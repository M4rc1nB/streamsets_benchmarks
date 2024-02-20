# Variables
SHELL := /bin/bash

ENV ?= prod
REPO := $(shell git remote get-url origin | sed -e 's/^.*\///' -e 's/.git//')
USER_ID ?= $(shell stat -c "%u:%g" .)
USERNAME ?= $(shell whoami)
DEFAULT_REGION ?= europe-west1

## Applications
TERRAFORM := terraform
TERRAFORM := DEFAULT_REGION=${DEFAULT_REGION} \
		TF_VAR_repo=${REPO} \
		TF_VAR_env=${ENV} \
		TF_VAR_your_initials=${USERNAME} \
		${TERRAFORM}

# Dependencies
depend:
	${TERRAFORM} get
	${TERRAFORM} init \
		-backend-config="bucket=sx-benchmarks" \
		-backend-config="prefix=terraform/${USERNAME}-state"


# Running
plan:
	@${TERRAFORM} plan ${TARGET}

deploy: apply

apply:
	@${TERRAFORM} apply -auto-approve ${TARGET}

destroy:
	@${TERRAFORM} destroy

.PHONY: plan apply test destroy

# QA
qa: lint

lint:
	${TERRAFORM} fmt -recursive -check -write=false

fmt:
	${TERRAFORM} fmt -diff

.PHONY: lint fmt

# Testing
test:
	@echo "Skipping test - none configured, use this for python or bash tests"

.PHONY: test

# Cleaning
clean:
	rm -rf .terraform
	rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
	rm -f *.lock.hcl

clean-all: clean

.PHONY: clean clean-all
