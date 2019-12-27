.PHONY: no_targets__ infra_create, infra_plan, infra_create_and_deploy, infra_destroy, \ 
	deploy_all, deploy_frontend, deploy_backend, deploy_seed, aws_login, ssh_agent

no_targets__:
	@echo You must indicate a target, please see the Makefile for valid parameters to this makefile such as "deploy_all", "deploy_seed", etc

aws_login:
	@echo Login with saml2aws to get temp credentiasl
	saml2aws login --force --profile=kube-the-hard-way

ssh_agent:
	@echo Configure ssh agent and add key
	eval 'ssh-agent -s'
	ssh-add ~/.ssh/kube_the_hard_way

