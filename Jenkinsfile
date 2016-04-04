stage 'Dev'
node('cloud') {
  git url: 'https://github.com/virginialee/sample.git'
  echo 'Do something?'
  runUnitTest()
}

def runUnitTest() {
  sh "cd api && ./ci_docker.sh"
}
