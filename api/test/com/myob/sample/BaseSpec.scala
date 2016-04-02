package com.myob.sample

import org.scalactic.TypeCheckedTripleEquals
import org.scalatest.concurrent.ScalaFutures
import org.scalatest.{BeforeAndAfter, FunSpec}
import org.scalatest.mock.MockitoSugar
import play.api.mvc.Results

class BaseSpec extends FunSpec with TypeCheckedTripleEquals with Results with ScalaFutures with MockitoSugar with BeforeAndAfter {

}
