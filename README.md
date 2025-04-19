# 🎞️ Serverless Movies API

## Architecture Diagram

![Movies API Architecture Diagram](Architecture%20Diagram.png)

## Authenticating in Azure with Terraform

To successfully provision the resources in Azure, the following environment variables need to be exported before running `terraform plan` or `terraform apply`:

- `ARM_CLIENT_ID=<your-client-id>`
- `ARM_CLIENT_SECRET=<your-client-secret>`
- `ARM_SUBSCRIPTION_ID=<your-subscription-id>` 
- `ARM_TENANT_ID=<your-tenant-id>`

To create the environment variables in Linux, use:
```bash
export ARM_CLIENT_ID="your-client-id"
```
To create them in Windows, use:
```commandline
set ARM_CLIENT_ID="your-client-id"
```
