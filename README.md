# ChatWorkのAPI使用回数をLambdaとDynamoDBを使って記録する

## 使い方

1. `terraform.tfvars.example`をコピーして`terraform.tfvars`を作成し、AWSの認証情報などを記述する
2. lambda_function下で`yarn isntall` or `npm install`
3. main.tfがある場所で`terraform apply`
4. 作成したAWSリソースを削除したい場合は`terraform destroy`

## Qiitaでも紹介しています
https://qiita.com/hareku/items/71960296e07cbe45ff11
