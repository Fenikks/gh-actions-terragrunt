# terragrunt-plan-all action

This Terragrunt action based on [dflook/terraform-github-actions](https://github.com/dflook/terraform-github-actions).

This actions generates a Terraform plan for all modules in the provided path.
If the triggering event relates to a PR it will add a comment on the PR containing the generated plan.


The `GITHUB_TOKEN` environment variable must be set for the PR comment to be added.
The action can be run on other events, which prints the plan to the workflow log.

## Inputs

* `path`

  Path to the Terraform root module to apply

  - Type: string
  - Optional
  - Default: The action workspace

* `tg_version`

  Terragrunt version required to run the plan

  - Type: string
  - Optional
  - Default: `0.52.4`

* `tf_version`

  Terraform version required to run the plan

  - Type: string
  - Optional
  - Default: `1.5.7`

* `parallelism`

  Limit the number of concurrent operations

  - Type: number
  - Optional
  - Default: The terraform default (10)

* `label`

  A friendly name for the environment the Terraform configuration is for.
  This will be used in the PR comment for easy identification.

  If set, must be the same as the `label` used in the corresponding `terraform-apply` command.

  - Type: string
  - Optional

* `add_github_comment`

  The default is `true`, which adds a comment to the PR with the results of the plan.
  Set to `changes-only` to add a comment only when the plan indicates there are changes to apply.
  Set to `false` to disable the comment - the plan will still appear in the workflow log.

  - Type: string
  - Optional
  - Default: true

* `destroy`

  Set to true to generate a plan to destroy all resources.

  This generates a plan in destroy mode.

  - Type: boolean
  - Optional
  - Default: false

## Environment Variables

* `GITHUB_TOKEN`

  The GitHub authorization token to use to create comments on a PR.
  The token provided by GitHub Actions can be used - it can be passed by
  using the `${{ secrets.GITHUB_TOKEN }}` expression, e.g.

  ```yaml
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ```

  The token provided by GitHub Actions has default permissions at GitHub's whim. You can see what it is for your repo under the repo settings.

  The minimum permissions are `pull-requests: write`.
  It will also likely need `contents: read` so the job can checkout the repo.

  You can also use any other App token that has `pull-requests: write` permission.

  You can use a fine-grained Personal Access Token which has repository permissions:
  - Read access to metadata
  - Read and Write access to pull requests

  You can also use a classic Personal Access Token which has the `repo` scope.

  The GitHub user or app that owns the token will be the PR comment author.

  - Type: string
  - Optional

* `TERRAFORM_ACTIONS_GITHUB_TOKEN`

  When this is set it is used instead of `GITHUB_TOKEN`, with the same behaviour.
  The GitHub Terraform provider also uses the `GITHUB_TOKEN` environment variable, 
  so this can be used to make the github actions and the Terraform provider use different tokens.

  - Type: string
  - Optional

* `TF_PLAN_COLLAPSE_LENGTH`

  When PR comments are enabled, the terraform output is included in a collapsable pane.
  
  If a terraform plan has fewer lines than this value, the pane is expanded
  by default when the comment is displayed.

  ```yaml
  env:
    TF_PLAN_COLLAPSE_LENGTH: 30
  ```

  - Type: integer
  - Optional
  - Default: 10

## Outputs

* `changes`

  Set to 'true' if the plan would apply any changes, 'false' if it wouldn't.

  - Type: boolean

* `json_plan_path`

  This is the path to the generated plan in [JSON Output Format](https://www.terraform.io/docs/internals/json-format.html)
  The path is relative to the Actions workspace.

  - Type: string

* `text_plan_path`

  This is the path to the generated plan in a human-readable format.
  The path is relative to the Actions workspace.

  - Type: string

* `to_add`

  The number of resources that would be added by this plan.

  - Type: number

* `to_change`

  The number of resources that would be changed by this plan.

  - Type: number

* `to_destroy`

  The number of resources that would be destroyed by this plan.

  - Type: number

* `run_id`

  If the root module uses the `remote` or `cloud` backend in remote execution mode, this output will be set to the remote run id.

  - Type: string

## Workflow events

When adding the plan to a PR comment (`add_github_comment` is set to `true`/`changes-only`), the workflow can be triggered by the following events:

  - pull_request
  - pull_request_review_comment
  - pull_request_target
  - pull_request_review
  - issue_comment, if the comment is on a PR (see below)
  - push, if the pushed commit came from a PR (see below)
  - repository_dispatch, if the client payload includes the pull_request url (see below)

When `add_github_comment` is set to `false`, the workflow can be triggered by any event.

### issue_comment

This event triggers workflows when a comment is made in a Issue, as well as a Pull Request.
Since running the action will only work in the context of a PR, the workflow should check that the comment is on a PR before running.

Also take care to checkout the PR ref.

```yaml
jobs:
  plan:
    if: ${{ github.event.issue.pull_request }}
    runs-on: ubuntu-latest
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          ref: refs/pull/${{ github.event.issue.number }}/merge

      - name: terraform apply
        uses: dflook/terraform-plan@v1
        with:
          path: my-terraform-config
```

### push

The pushed commit must have come from a Pull Request. Typically this is used to trigger a workflow that runs on the main branch after a PR has been merged.

### repository_dispatch

This event can be used to trigger a workflow from another workflow. The client payload must include the pull_request api url of where the plan PR comment should be added.

A minimal example payload looks like:
```json
{
  "pull_request": {
    "url": "https://api.github.com/repos/dflook/terraform-github-actions/pulls/1"
  }
}
```

## Example usage

### Automatically generating a plan

This example workflow runs on every push to an open pull request,
and create or updates a comment with the terraform plan

```yaml
name: PR Plan

on: [pull_request]

permissions:
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    name: Create terraform plan
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}            
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: terraform plan
        uses: Fenikks/terragrunt-plan-all@v1
        with:
          path: my-terraform-config
```

### A full example of inputs

This example workflow demonstrates most of the available inputs:
- The environment variables are set at the workflow level.
- The PR comment will be labelled `production`, and the plan will use the `prod` workspace.
- Variables are read from `env/prod.tfvars`, with `turbo_mode` overridden to `true`.
- The backend config is taken from `env/prod.backend`, and the token is set from a secret.

```yaml
name: PR Plan

on: [pull_request]

env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

permissions:
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    name: Create Terraform plan
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: terraform plan
        uses: Fenikks/terragrunt-plan-all@v1
        with:
          path: my-terraform-config
          label: production
```

### Generating a plan using a comment

This workflow generates a plan on demand, triggered by someone
commenting `terraform plan` on the PR. The action will create or update
a comment on the PR with the generated plan.

```yaml
name: Terraform Plan

on: [issue_comment]

permissions:
  contents: read
  pull-requests: write

jobs:
  plan:
    if: ${{ github.event.issue.pull_request && contains(github.event.comment.body, 'terraform plan') }}
    runs-on: ubuntu-latest
    name: Create Terraform plan
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          ref: refs/pull/${{ github.event.issue.number }}/merge

      - name: terraform plan
        uses: dflook/terraform-plan@v1
        with:
          path: my-terraform-config
```
