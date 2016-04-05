## Steps for creating a new service

- Create secret and upload to s3 bucket, suggest to turn on server-side encryption
- Subscribe to SNS topic (need to be done manually)
- Setup Jenkins
  * Review Security Group setup
  * Plugins
    * Copy Artifact
    * HTML Publisher
    * Workspace Cleanup
    * Role-based Authorization Strategy
  * From Jenkins 1.641
    * https://wiki.jenkins-ci.org/display/JENKINS/Configuring+Content+Security+Policy
    * System.setProperty("hudson.model.DirectoryBrowserSupport.CSP", "")
