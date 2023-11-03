#!/bin/bash

set -euo pipefail

# Every file written to disk should use one of these directories
STEP_TMP_DIR="/tmp"
PLAN_OUT_DIR="/tmp/plan"
JOB_TMP_DIR="$HOME/.gh-actions-terragrunt"
WORKSPACE_TMP_DIR=".gh-actions-terragrunt/$(random_string)"
mkdir -p $PLAN_OUT_DIR
readonly STEP_TMP_DIR JOB_TMP_DIR WORKSPACE_TMP_DIR PLAN_OUT_DIR
export STEP_TMP_DIR JOB_TMP_DIR WORKSPACE_TMP_DIR PLAN_OUT_DIR


# shellcheck source=../workflow_commands.sh
source /usr/local/workflow_commands.sh

function debug() {
    debug_cmd ls -la /root
    debug_cmd pwd
    debug_cmd ls -la
    debug_cmd ls -la "$HOME"
    debug_cmd printenv
    debug_file "$GITHUB_EVENT_PATH"
    echo
}

function setup() {
    if [[ "$INPUT_PATH" == "" ]]; then
        error_log "input 'path' not set"
        exit 1
    fi

    if [[ ! -d "$INPUT_PATH" ]]; then
        error_log "Path does not exist: \"$INPUT_PATH\""
        exit 1
    fi

    if [[ ! -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
        if [[ -v GITHUB_TOKEN ]]; then
            export TERRAFORM_ACTIONS_GITHUB_TOKEN="$GITHUB_TOKEN"
        fi
    fi
    
    if ! github_comment_react +1 2>"$STEP_TMP_DIR/github_comment_react.stderr"; then
        debug_file "$STEP_TMP_DIR/github_comment_react.stderr"
    fi

    start_group "Installing Terragrunt and Terraform"

    # install terragrung and terraform
    local TG_VERSION
    local TF_VERSION
    
    if [[ -v INPUT_TG_VERSION ]]; then
        TG_VERSION=$INPUT_TG_VERSION
    fi

    if [[ -v INPUT_TF_VERSION ]]; then
        TF_VERSION=$INPUT_TF_VERSION
    fi

    curl -Lo /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VERSION}/terragrunt_linux_amd64"
    chmod +x /usr/local/bin/terragrunt
    curl -o /tmp/terraform_${TF_VERSION}_linux_amd64.zip https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
    unzip /tmp/terraform_${TF_VERSION}_linux_amd64.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/terraform

    end_group

    detect-tfmask
}

function set-common-plan-args() {
    PLAN_ARGS=""
    PARALLEL_ARG=""

    if [[ "$INPUT_PARALLELISM" -ne 0 ]]; then
        PARALLEL_ARG="--terragrunt-parallelism $INPUT_PARALLELISM"
    fi

    if [[ -v INPUT_DESTROY ]]; then
        if [[ "$INPUT_DESTROY" == "true" ]]; then
            PLAN_ARGS="$PLAN_ARGS -destroy"
        fi
    fi
    export PLAN_ARGS
}

function plan() {

    # shellcheck disable=SC2086
    debug_log terragrunt run-all plan -input=false -no-color -detailed-exitcode -lock-timeout=300s $PARALLEL_ARG -out=plan.out '$PLAN_ARGS'  # don't expand PLAN_ARGS

    MODULE_PATHS=$(find $INPUT_PATH -mindepth 2 -name terragrunt.hcl -exec dirname {} \;)

    set +e
    # shellcheck disable=SC2086
    (cd "$INPUT_PATH" && terragrunt run-all plan -input=false -no-color -detailed-exitcode -lock-timeout=300s $PARALLEL_ARG -out=plan.out $PLAN_ARGS) \
        2>"$STEP_TMP_DIR/terraform_plan.stderr" \
        | $TFMASK 
        
        # \
        # | tee /dev/fd/3 "$STEP_TMP_DIR/terraform_plan.stdout" \
        # | compact_plan \
        #     >"$STEP_TMP_DIR/plan.txt"

    # shellcheck disable=SC2034
    #PLAN_EXIT=${PIPESTATUS[0]}
    for i in $MODULE_PATHS; do 
        plan_name=plan-${i//\//-}
        terragrunt show plan.out --terragrunt-working-dir $i -no-color|tee $PLAN_OUT_DIR/$plan_name
        #compact_plan($(cat $PLAN_OUT_DIR/$plan_name)) > $PLAN_OUT_DIR/$plan_name
    done
    set -e
}

function job_markdown_ref() {
    echo "[${GITHUB_WORKFLOW} #${GITHUB_RUN_NUMBER}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})"
}

function detect-tfmask() {
    TFMASK="tfmask"
    if ! hash tfmask 2>/dev/null; then
        TFMASK="cat"
    fi

    export TFMASK
}












function test-terraform-version() {
    local OP="$1"
    local VER="$2"

    python3 -c "exit(0 if ($TERRAFORM_VER_MAJOR, $TERRAFORM_VER_MINOR, $TERRAFORM_VER_PATCH) $OP tuple(int(v) for v in '$VER'.split('.')) else 1)"
}




function execute_run_commands() {
    if [[ -v TERRAFORM_PRE_RUN ]]; then
        start_group "Executing TERRAFORM_PRE_RUN"

        echo "Executing init commands specified in 'TERRAFORM_PRE_RUN' environment variable"
        printf "%s" "$TERRAFORM_PRE_RUN" >"$STEP_TMP_DIR/TERRAFORM_PRE_RUN.sh"
        disable_workflow_commands
        bash -xeo pipefail "$STEP_TMP_DIR/TERRAFORM_PRE_RUN.sh"
        enable_workflow_commands

        end_group
    fi
}



function relative_to() {
    local absbase
    local relpath

    absbase="$1"
    relpath="$2"
    realpath --no-symlinks --canonicalize-missing --relative-to="$absbase" "$relpath"
}

##
# Initialize terraform without a backend
#
# This only validates and installs plugins
function init() {
    start_group "Initializing $TOOL_PRODUCT_NAME"

    rm -rf "$TF_DATA_DIR"
    debug_log $TOOL_COMMAND_NAME init -input=false -backend=false
    (cd "$INPUT_PATH" && $TOOL_COMMAND_NAME init -input=false -backend=false)

    end_group
}

function set-init-args() {
    INIT_ARGS=""

    if [[ -n "$INPUT_BACKEND_CONFIG_FILE" ]]; then
        for file in $(echo "$INPUT_BACKEND_CONFIG_FILE" | tr ',' '\n'); do

            if [[ ! -f "$file" ]]; then
                error_log "Path does not exist: \"$file\""
                exit 1
            fi

            INIT_ARGS="$INIT_ARGS -backend-config=$(relative_to "$INPUT_PATH" "$file")"
        done
    fi

    if [[ -n "$INPUT_BACKEND_CONFIG" ]]; then
        for config in $(echo "$INPUT_BACKEND_CONFIG" | tr ',' '\n'); do
            INIT_ARGS="$INIT_ARGS -backend-config=$config"
        done
    fi

    export INIT_ARGS
}

function random_string() {
    python3 -c "import random; import string; print(''.join(random.choice(string.ascii_lowercase) for i in range(8)))"
}

function write_credentials() {
    format_tf_credentials >>"$HOME/.terraformrc"
    chown --reference "$HOME" "$HOME/.terraformrc"
    netrc-credential-actions >>"$HOME/.netrc"
    chown --reference "$HOME" "$HOME/.netrc"

    chmod 700 /.ssh
    if [[ -v TERRAFORM_SSH_KEY ]]; then
        echo "$TERRAFORM_SSH_KEY" >>/.ssh/id_rsa
        chmod 600 /.ssh/id_rsa
    fi

    debug_cmd git config --list
}



function force_unlock() {
    echo "Unlocking state with ID: $INPUT_LOCK_ID"
    debug_log $TOOL_COMMAND_NAME force-unlock -force $INPUT_LOCK_ID
    (cd "$INPUT_PATH" && $TOOL_COMMAND_NAME force-unlock -force $INPUT_LOCK_ID)
}

function fix_owners() {
    debug_cmd ls -la "$GITHUB_WORKSPACE"
    if [[ -d "$GITHUB_WORKSPACE/.gh-actions-terragrunt" ]]; then
        chown -R --reference "$GITHUB_WORKSPACE" "$GITHUB_WORKSPACE/.gh-actions-terragrunt" || true
        debug_cmd ls -la "$GITHUB_WORKSPACE/.gh-actions-terragrunt"
    fi

    debug_cmd ls -la "$HOME"
    if [[ -d "$HOME/.gh-actions-terragrunt" ]]; then
        chown -R --reference "$HOME" "$HOME/.gh-actions-terragrunt" || true
        debug_cmd ls -la "$HOME/.gh-actions-terragrunt"
    fi
    if [[ -d "$HOME/.terraform.d" ]]; then
        chown -R --reference "$HOME" "$HOME/.terraform.d" || true
        debug_cmd ls -la "$HOME/.terraform.d"
    fi

    if [[ -d "$INPUT_PATH" ]]; then
        debug_cmd find "$INPUT_PATH" -regex '.*/zzzz-gh-actions-terragrunt-[0-9]+\.auto\.tfvars' -print -delete || true
    fi
}

trap fix_owners EXIT
