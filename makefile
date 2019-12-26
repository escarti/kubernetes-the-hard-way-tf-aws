.PHONY: no_targets__ infra_create, infra_plan, infra_create_and_deploy, infra_destroy, \ 
	deploy_all, deploy_frontend, deploy_backend, deploy_seed, aws_login, ssh_agent

no_targets__:
	@echo You must indicate a target, please see the Makefile for valid parameters to this makefile such as "deploy_all", "deploy_seed", etc

aws_login:
	@echo Login with saml2aws to get temp credentiasl
	saml2aws login --force --profile=hf-sandbox-account

ssh_agent:
	@echo Configure ssh agent and add key
	eval 'ssh-agent -s'
	ssh-add ~/.ssh/hf_infra_sandbox_application_key

infra_create_and_deploy:
	@echo Deploying all infrastructure and BE,FE code
	@echo applying terraform infrastructure
	(eval 'ssh-agent -s'; ssh-add ~/.ssh/hf_infra_sandbox_application_key) && saml2aws login --force --profile=hf-sandbox-account && terraform apply && (./modules/hf-infra-core-application/deploy_all.sh $(ENV) all)

infra_create:
	@echo applying terraform infrastructure
	(eval 'ssh-agent -s'; ssh-add ~/.ssh/hf_infra_sandbox_application_key) && saml2aws login --force --profile=hf-sandbox-account && terraform apply

infra_destroy:
	@echo Destroy all infrastructure
	saml2aws login --force --profile=hf-sandbox-account && terraform destroy

infra_plan:
	@echo Checks infra for deviations
	saml2aws login --force --profile=hf-sandbox-account && terraform plan

# V2 Docker-based deployments

ENV?=sandbox

deploy_all:
	@echo deploys FE,BE and Socker Server on $(ENV)infrastructure
	(eval 'ssh-agent -s'; ssh-add ~/.ssh/hf_infra_sandbox_application_key) && ./modules/hf-infra-core-application/deploy_all.sh $(ENV) all

deploy_backend:
	@echo deploys BE on $(ENV)infrastructure
	(eval 'ssh-agent -s'; ssh-add ~/.ssh/hf_infra_sandbox_application_key) && ./modules/hf-infra-core-application/deploy_all.sh $(ENV) backend

deploy_frontend:
	@echo deploys Frontend on $(ENV) infrastructure
	(eval 'ssh-agent -s'; ssh-add ~/.ssh/hf_infra_sandbox_application_key) && ./modules/hf-infra-core-application/deploy_all.sh $(ENV) frontend

deploy_seed:
	@echo Seeds database on $(ENV) infrastructure
	(eval 'ssh-agent -s'; ssh-add ~/.ssh/hf_infra_sandbox_application_key) && ./modules/hf-infra-core-application/deploy_all.sh $(ENV) seed

