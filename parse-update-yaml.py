#import yaml
import os
import sys
import ruamel.yaml

'''
  * Script Name         :  parse-update-yaml.py
  * Purpose             :  To update manifest YAML file to scale down and scale up application providing various scenarios mentioned below
                        	# IKS AWS region specific operations
                        	# Deployment environment specific operations
                        	# Enable or disable PreSync or PostSync hooks
                        	# Enable or Diable horizontal scaling
                        	# Directing traffic to maintenance pods and updating replicas to 0
  * Author              : Vivek Dubey(https://github.com/vivekdubeyvkd)
'''

'''
	Try it out on your pre-prod/lowers environments first before using it for production environments. You can make changes to the scripts as per your requirements and contribute back as well in case if the changes are generic.
'''

'''
	pre-requisites;
		1. Install Python3
		2. Instal Python module ruamel.yaml, you can use one of the below commands
			pip3 install ruamel.yaml
			or
			pip install ruamel.yaml
			or
			python3 -m pip install ruamel.yaml
			or
			python -m pip install ruamel.yaml
'''

'''
	usage:
	    export appRepoOrgName="GitHubOrg/GitHubRepoName"
	    export THIS_DB_TYPE="DB_TYPE" #Valid values for THIS_DB_TYPE: oracle or postgres
		  python3 parse-update-yaml.py [INPUT_MANIFEST_YAML_FILE_WITH_PATH] [INPUT_OPTIONS] [INPUT_APP_IMAGE_NAME]


	more details on input options:	
		INPUT_MANIFEST_YAML_FILE_WITH_PATH: Mandatory
		INPUT_OPTIONS: Mandatory, valid values sd or su or suwm1pod or suwmallpod
  			sd: Scale Down
  			su: Scale up by keeping changes from GitHub Tag as it is without SyncJobs
  			suwm1pod: Scale up one pods with maintenance, without HorizontalPodAutoscaler and SyncJobs
  			suwmallpod: Scale up all pods with maintenance and without SyncJobs
		INPUT_APP_IMAGE_NAME: Optional, default value is NA
'''

# parse-update-yaml.py
yaml = ruamel.yaml.YAML()
yaml.preserve_quotes = True
yaml.width = 4096666

# app list which does not need any change service kind of attributes or yaml docs in the main doc
IGNORE_SERVICE_CHANGE_APP_LIST = ["githuborg1/githubrepo1","githuborg2/githubrepo2"]

def checkAndUpdateDbType(manifestYamlDoc, newDbType):
	if "data" in manifestYamlDoc:
		if "monolithDb" in manifestYamlDoc['data']:
			manifestYamlDoc['data']['monolithDb'] = newDbType


def checkAndUpdateAppImageName(manifestYamlDoc, newAppImage):
	if newAppImage != "NA":
		if 'containers' in manifestYamlDoc['spec']['template']['spec']:
			containersList = manifestYamlDoc['spec']['template']['spec']['containers']
			for container in containersList:
				if container['name'] == "app":
					container['image'] = newAppImage


def scaleUpWithMaitenanceAndOnePodWithoutSyncJobs(inputYamlFile, inputAppImageName):
	stream = open(inputYamlFile, 'r')
	yaml_docs = list(yaml.load_all(stream))
	new_yaml_docs = []
	appRepoOrgName = os.environ.get('appRepoOrgName')
	dbType = os.environ.get('THIS_DB_TYPE')
	
	for doc in yaml_docs:
		if doc['kind'] == "HorizontalPodAutoscaler":
			continue
		elif doc['kind'] == "ConfigMap":
			checkAndUpdateDbType(doc, dbType)
		elif doc['kind'] == "Job":
			if "argocd.argoproj.io/hook" in doc['metadata']['annotations']:
				hookType = doc['metadata']['annotations']['argocd.argoproj.io/hook']
				if hookType == 'PreSync' or hookType == 'PostSync':
					continue
		elif doc['kind'] == "Service":
			if 'app' in doc['spec']['selector']:
				if doc['spec']['selector']['app'] != "your-app-name":
					if appRepoOrgName not in IGNORE_SERVICE_CHANGE_APP_LIST:
						doc['spec']['selector']['app'] = 'maintenance'
		elif doc['kind'] == "Deployment" or doc['kind'] == "Rollout":
			if 'labels' in doc['metadata']:  
				if doc['metadata']['labels']['app'] != "maintenance":
					if 'replicas' in doc['spec']:
						if doc['metadata']['name'] != "your-service-name":
							doc['spec']['replicas'] = 1
					else:
						newDict = {"replicas" : 1}
						newDict.update(doc['spec'])
						doc['spec'] = newDict

			checkAndUpdateAppImageName(doc, inputAppImageName)

		new_yaml_docs.append(doc)

	# write back mnifest YAML file
	with open(inputYamlFile, 'w') as file:
	    yaml.dump_all(new_yaml_docs, file)


def scaleUpWithMaitenanceAndAllPodsWithoutSyncJobs(inputYamlFile, inputAppImageName):
	stream = open(inputYamlFile, 'r')
	yaml_docs = list(yaml.load_all(stream))
	new_yaml_docs = []
	appRepoOrgName = os.environ.get('appRepoOrgName')
	dbType = os.environ.get('THIS_DB_TYPE')
	
	for doc in yaml_docs:
		if doc['kind'] == "Job":
			if "argocd.argoproj.io/hook" in doc['metadata']['annotations']:
				hookType = doc['metadata']['annotations']['argocd.argoproj.io/hook']
				if hookType == 'PreSync' or hookType == 'PostSync':
					continue
		elif doc['kind'] == "ConfigMap":
			checkAndUpdateDbType(doc, dbType)					
		elif doc['kind'] == "Service":
			if 'app' in doc['spec']['selector']:
				if doc['spec']['selector']['app'] != "your-app-name":
					if appRepoOrgName not in IGNORE_SERVICE_CHANGE_APP_LIST:
						doc['spec']['selector']['app'] = 'maintenance'
		elif doc['kind'] == "Deployment" or doc['kind'] == "Rollout":		
			checkAndUpdateAppImageName(doc, inputAppImageName)

		new_yaml_docs.append(doc)

	# write back mnifest YAML file
	with open(inputYamlFile, 'w') as file:
	    yaml.dump_all(new_yaml_docs, file)


def scaleUpWithoutSyncJobs(inputYamlFile, inputAppImageName):
	stream = open(inputYamlFile, 'r')
	yaml_docs = list(yaml.load_all(stream))
	new_yaml_docs = []
	dbType = os.environ.get('THIS_DB_TYPE')

	for doc in yaml_docs:
		if doc['kind'] == "Job":
			if "argocd.argoproj.io/hook" in doc['metadata']['annotations']:
				hookType = doc['metadata']['annotations']['argocd.argoproj.io/hook']
				if hookType == 'PreSync' or hookType == 'PostSync':
					continue
		elif doc['kind'] == "ConfigMap":
			checkAndUpdateDbType(doc, dbType)					
		elif doc['kind'] == "Deployment" or doc['kind'] == "Rollout":
			checkAndUpdateAppImageName(doc, inputAppImageName)

		new_yaml_docs.append(doc)

	# write back mnifest YAML file
	with open(inputYamlFile, 'w') as file:
	    yaml.dump_all(new_yaml_docs, file)

def scaleDown(inputYamlFile):
	appRepoOrgName = os.environ.get('appRepoOrgName')
	stream = open(inputYamlFile, 'r')
	yaml_docs = list(yaml.load_all(stream))
	new_yaml_docs = []

	for doc in yaml_docs:
		# if doc['kind'] == "HorizontalPodAutoscaler":
		# 	continue
		if doc['kind'] == "Job":
			if "argocd.argoproj.io/hook" in doc['metadata']['annotations']:
				hookType = doc['metadata']['annotations']['argocd.argoproj.io/hook']
				if hookType == 'PreSync' or hookType == 'PostSync':
					continue
		elif doc['kind'] == "Service":
			if 'app' in doc['spec']['selector']:
				if doc['spec']['selector']['app'] != "your-app-name":
					if appRepoOrgName not in IGNORE_SERVICE_CHANGE_APP_LIST:
						doc['spec']['selector']['app'] = 'maintenance'
		elif doc['kind'] == "Deployment" or doc['kind'] == "Rollout":
			if 'labels' in doc['metadata']: 
				if doc['metadata']['labels']['app'] != "maintenance":
					if 'replicas' in doc['spec']:
						if doc['metadata']['name'] != "your-service-name":
							doc['spec']['replicas'] = 0
					else:
						newDict = {"replicas" : 0}
						newDict.update(doc['spec'])
						doc['spec'] = newDict
		elif doc['kind'] == "CronJob":
			if doc['metadata']['name'] == 'datasync-cronjob':
				continue

		new_yaml_docs.append(doc)

	#print(yaml.dump(new_yaml_docs, default_flow_style=False))

	# write back mnifest YAML file
	with open(inputYamlFile, 'w') as file:
	    yaml.dump_all(new_yaml_docs, file)

def parseUpdateMnifestYaml(yamlFile, inputOptionVal, newAppImageName):
	if inputOptionVal == "sd":
		scaleDown(yamlFile)
	elif inputOptionVal == "su":
		scaleUpWithoutSyncJobs(yamlFile, newAppImageName)
	elif inputOptionVal == "suwm1pod":
		scaleUpWithMaitenanceAndOnePodWithoutSyncJobs(yamlFile, newAppImageName)
	elif inputOptionVal == "suwmallpod":
		scaleUpWithMaitenanceAndAllPodsWithoutSyncJobs(yamlFile, newAppImageName)
	else:
		pass

def validateScriptArgs(scriptArgs):
    if scriptArgs and (len(scriptArgs) == 2 or len(scriptArgs) == 3):
        return "valid"
    else:
        return

def main(scriptArgs):
    if validateScriptArgs(scriptArgs):
        inputYamlFileName = scriptArgs[0]
        optionVal = scriptArgs[1]
        appInputImageName = "NA"
        if len(scriptArgs) == 3:
        	appInputImageName = scriptArgs[2]
        parseUpdateMnifestYaml(inputYamlFileName, optionVal, appInputImageName)
    else:
    	print('''
++++++++++++++++++++++++++++++++++ ERROR  ++++++++++++++++++++++++++++++++++"
		Invalid input params, you need to pass Manifest YAML file and Scale operation values as input, please check and rerun .... exiting .....
++++++++++++++++++++++++++++++++++ ERROR  ++++++++++++++++++++++++++++++++++"
    	''')

if __name__ == "__main__":
    scriptArgs = sys.argv[1:]
    main(scriptArgs)

