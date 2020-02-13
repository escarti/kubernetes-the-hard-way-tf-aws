# 01. Prerequisites 

We are going to define the infrastructure as code with terraform and deploy it on AWS. We are going to provision our instances using Ansible so we will need to install all those ressources.

1. Install [AWS CLI](https://docs.aws.amazon.com/es_es/cli/latest/userguide/install-macos.html)

    ``brew install awscli``

2. Install ansible

    ``brew install ansible``

3. Install terraform 0.12.19. I recommend using [tfswitch](https://warrensbox.github.io/terraform-switcher/) for switching between terraform versions 
 
   ``brew install warrensbox/tap/tfswitch``

   ``tfswitch 0.12.19``

4. Create a profile for your AWS account

    ``aws configure --profile=kube-the-hard-way``

5. If you are a Xing member you can use [saml2aws](https://github.com/Versent/saml2aws) to get temporary AWS keys on demand 

5. Run saml2aws to create a default config:

    ``saml2aws configure -a default``

5. Execute saml2aws login to generate temporary credentials for "saml" profile

    ``saml2aws login --force --profile=kube-the-hard-way``