.PHONY: no_targets__ aws_login, ssh_agent, init, create_infra, destroy_and_clean, all

no_targets__:
	@echo You must indicate a target, please see the Makefile for valid parameters to this makefile

aws_login:
	@echo Login with saml2aws to get temp credentiasl
	saml2aws login --force --profile=kube-the-hard-way

ssh_agent:
	@echo Configure ssh agent and add key
	eval 'ssh-agent -s'
	ssh-add ~/.ssh/kube_the_hard_way

init:
	@echo Initial commands to start working: Get temp AWS credentials and add key to the ssh agent.
	saml2aws login --force --profile=kube-the-hard-way
	eval 'ssh-agent -s'
	ssh-add ~/.ssh/kube_the_hard_way

create_infra:
	@echo Create the infrastructure from scratch
	saml2aws login --profile=kube-the-hard-way
	cd terraform && terraform apply -auto-approve 

destroy_and_clean:
	@echo Destroy infrastructure and clean tmp files 
	saml2aws login --profile=kube-the-hard-way
	cd terraform && terraform destroy
	cd tmp && rm *

all:
	@echo Do all
	saml2aws login --profile=kube-the-hard-way
	eval 'ssh-agent -s'
	ssh-add ~/.ssh/kube_the_hard_way
	mkdir -p tmp
	cp ansible.cfg tmp/ansible.cfg
	cd tmp && ./../scripts/04_generate_client_certificates.sh\
  	&& ./../scripts/04_generate_server_certificates.sh\
  	&& ./../scripts/04_distribute_certificate_files.sh\
	&& ./../scripts/05_generate_kubeconfig_files.sh\
	&& ./../scripts/05_distribute_kubeconfig_files.sh\
	&& ./../scripts/06_generate_distribute_encryption_keys.sh\
	&& ./../scripts/07_bootstrap_etcd_cluster.sh\
	&& ./../scripts/08_bootstrap_controllers.sh\
	&& ./../scripts/09-bootstrapping-kubernetes-workers.sh\
	&& ./../scripts/10-configuring-kubectl.sh\
	&& ./../scripts/12-dns-addon.sh