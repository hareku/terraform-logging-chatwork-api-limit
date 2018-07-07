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
    await new Promise(resolve => setTimeout(resolve, waitUnixTime * 10))

    const responseForLogging = await axios.get('https://api.chatwork.com/v2/me')
    const limit = Number(responseForLogging.headers['x-ratelimit-limit'])
    const remaining = Number(responseForLogging.headers['x-ratelimit-remaining'])

    const dbClient = new AWS.DynamoDB.DocumentClient()
    await dbClient.put({
        TableName: "ChatWorkApiRateLimit",
        Item: {
          ResetAt: moment.unix(nextResetUnixTime).tz('Asia/Tokyo').format('YYYY-MM-DD HH:mm:ssZ'),
          Remaining: remaining,
          Called: limit - remaining
        }
      }).promise()
  } catch (error) {
    console.error(`[Error]: ${JSON.stringify(error)}`)
    return error
  }
}
