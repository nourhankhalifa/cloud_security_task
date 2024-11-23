# AWS Infrastructure and Nginx Setup

This project automates the provisioning of AWS infrastructure and the setup of an Nginx server using Terraform and Ansible.

## Prerequisites

1. Ensure you have **Terraform** and **Ansible** installed on your system.
2. Install Python and required dependencies for Ansible, if not already installed.
3. Ensure you have an AWS account and access credentials.

---

## Steps to Run the Project

### 1. Create a `main.tfvars` File

Create a `main.tfvars` file in the project directory and provide your AWS credentials. The file should look like this:

```hcl
access_key = "<Your AWS Access Key>"
secret_key = "<Your AWS Secret Key>"
```

### 2. Provision AWS Infrastructure

Run the Terraform script to provision the required AWS infrastructure:

```bash
terraform plan -var-file=main.tfvars
terraform apply -var-file=main.tfvars
```

This will:

- Create AWS resources (VPC, subnets, EC2 instances, etc.).
- Generate two files:
  - `ansible_hosts`: Used as the inventory file for Ansible.
  - `web_server.pem`: Private key to connect to the EC2 instances.
- Output the `bastion_ip` that is required for Ansible.

---

### 3. Update File Permissions

Set the appropriate permissions for the generated private key file:

```bash
chmod 600 web_server.pem
```

---

### 4. Run the Ansible Playbook

Execute the Ansible playbook to configure the web server. Replace `<IP>` with the actual `bastion_ip` value output by Terraform:

```bash
ansible-playbook -i ansible_hosts nginx_setup.yml --extra-vars '{"bastion_ip": "<IP>", "ansible_ssh_user": "ec2-user"}'
```

This will:

- Connect to the bastion host and private EC2 instances.
- Set up Nginx with a custom index file and upload a logo.

---

## Outputs

After successful execution, your Nginx server will be accessible via the CloudFront distribution URL or other configurations you set up.

---

## Troubleshooting

1. **Permission Denied Errors:**
   - Ensure `web_server.pem` has the correct permissions (`chmod 600 web_server.pem`).
   - Confirm that your AWS credentials are valid in the `main.tfvars` file.

2. **Connection Issues:**
   - Verify the `bastion_ip` is correctly passed in the `ansible-playbook` command.
   - Ensure your local IP is whitelisted for SSH access in the Terraform configuration.

3. **Infrastructure Changes:**
   - If you make changes to the Terraform configuration, rerun `terraform apply -var-file=main.tfvars` to update the infrastructure.

---

## Notes

### VPC Origins
Since CloudFront recently introduced support for VPC origins, Terraform does not yet have dedicated resources for managing this feature. As a result, you will need to configure the VPC origin manually. This involves adding the origin in the CloudFront distribution settings and updating the behavior to point to the newly created origin.

- The project is designed for learning and demonstration purposes.
- Ensure you clean up resources after testing to avoid unnecessary AWS charges:

```bash
terraform destroy -var-file=main.tfvars
```