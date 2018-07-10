const AWS = require('aws-sdk')
const moment = require('moment-timezone')
const axios = require('axios')
axios.defaults.headers.common['X-ChatWorkToken'] = process.env.ChatWorkToken

exports.handler = async (event, context) => {
  try {
    // 次にAPI制限がリセットされる10秒前まで待機する
    const responseForWaiting = await axios.get('https://api.chatwork.com/v2/me')
    const nextResetUnixTime = Number(responseForWaiting.headers['x-ratelimit-reset'])
    const waitUnixTime = nextResetUnixTime - moment().tz('Asia/Tokyo').unix() - 10
    await new Promise(resolve => setTimeout(resolve, waitUnixTime * 1000))

    const responseForLogging = await axios.get('https://api.chatwork.com/v2/me')
    const remaining = Number(responseForLogging.headers['x-ratelimit-remaining'])

    const putLogParams = {
      logEvents: [
        {
          message: `${remaining}`,
          timestamp: nextResetUnixTime * 1000
        }
      ],
      logGroupName: 'ChatWorkAPI',
      logStreamName: 'APIRemaining'
    }

    const logsClient = new AWS.CloudWatchLogs()
    const sequenceTokenIfError = await logsClient.putLogEvents(putLogParams).promise()
      .catch(error => {
        if (error && error.code === 'InvalidSequenceTokenException') {
          // nextSequenceToken
          return error.message.match(/[0-9]+/).pop()
        }
        return Promise.reject(error)
      })

    if (sequenceTokenIfError) {
      putLogParams.sequenceToken = sequenceTokenIfError
      await logsClient.putLogEvents(putLogParams).promise()
    }
  } catch (error) {
    console.error(`[Error]: ${JSON.stringify(error)}`)
    return error
  }
}
