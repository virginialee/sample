stage 'Unit Test'
node('cloud') {
  git url: 'https://github.com/virginialee/sample.git'
  echo 'Run unit tests'
  runUnitTest()
}

stage 'Assemble'
node('cloud') {
  echo 'Assemble ami' 
  buildAmi()
}

def runUnitTest() {
  sh "cd api && ./ci_docker.sh"
}

def buildAmi() {
  sh "cd ops && ./assemble_docker.sh"
}
