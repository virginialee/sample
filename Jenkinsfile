stage 'Dev'
node {
  checkout scm
  echo 'Do something?'
  runUnitTest()
}

def runUnitTest() {
  sh "cd api && ./ci_docker.sh"
}
