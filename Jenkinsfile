stage 'Dev'
node {
  checkout scm
  echo 'Do something?'
  runUnitTest
}

def runUnitTest {
  node {
    sh "cd api && ./ci_docker.sh"
  }
}
