.PHONY: no_targets__ aws_login, ssh_agent

no_targets__:
	@echo You must indicate a target, please see the Makefile for valid parameters to this makefile

aws_login:
	@echo Login with saml2aws to get temp credentiasl
	saml2aws login --force --profile=kube-the-hard-way

ssh_agent:
	@echo Configure ssh agent and add key
	eval 'ssh-agent -s'
	ssh-add ~/.ssh/kube_the_hard_way

all:
	@echo Do all
	saml2aws login --force --profile=kube-the-hard-way
	eval 'ssh-agent -s'
	ssh-add ~/.ssh/kube_the_hard_way
	mkdir -p tmp 
	cd tmp && ./../scripts/04_generate_client_certificates.sh\
  	&& ./../scripts/04_generate_server_certificates.sh\
  	&& ./../scripts/04_distribute_certificate_files.sh\
	&& ./../scripts/05_generate_kubeconfig_files.sh\
	&& ./../scripts/05_distribute_kubeconfig_files.sh\
	&& ./../scripts/06_generate_distribute_encryption_keys.sh