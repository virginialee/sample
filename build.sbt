name := "sample"

organization := "com.myob"

version := "1.0-SNAPSHOT"

lazy val sample = (project in file(".")).enablePlugins(PlayScala)

scalaVersion := "2.11.7"

libraryDependencies ++= Seq(
  cache,
  ws,
  "com.typesafe.play"         %% "play-slick"         % "1.1.1"                       withSources(),
  "org.scalatestplus.play" %% "scalatestplus-play"           % "1.5.0"     % "test",
  "org.mockito"            %  "mockito-core"                 % "1.10.19"   % "test"
)

libraryDependencies += filters

resolvers += "scalaz-bintray" at "http://dl.bintray.com/scalaz/releases"
resolvers += "sonatype-releases" at "https://oss.sonatype.org/content/repositories/releases/"

// Play provides two styles of routers, one expects its actions to be injected, the
// other, legacy style, accesses its actions statically.
routesGenerator := InjectedRoutesGenerator

//Coverage
scalastyleFailOnError := false
coverageMinimum := 80
coverageFailOnMinimum := false
coverageExcludedPackages := "<empty>;Reverse.*;router.Routes.*;views.html\\.*;com.myob.stub.*;"



// local run command
addCommandAlias("check", ";scalastyle; test:scalastyle")
addCommandAlias("full", ";clean ;compile ;test ;check")
addCommandAlias("report", ";clean;coverage;test;coverageReport")
addCommandAlias("run-local", "run -Dconfig.resource=local/application.conf -Dlogger.resource=local/logback.xml")
//addCommandAlias("db-migrate", "flywayMigrate")
//addCommandAlias("db-clean", "flywayClean")

javaOptions in Test += "-Dconfig.resource=" + Option(System.getProperty("env")).getOrElse("sit") + "/application.conf"


fork in run := true
