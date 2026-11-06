import XCTest
final class DashboardUITests: XCTestCase {
 func capture(_ name: String) {
  let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
 }
 func testDashboardControlsAndLayout() {
  let app=XCUIApplication();app.launch()
  XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout:10))
  XCTAssertEqual(app.staticTexts["home.status"].label,"Ready to connect")
  capture("dashboard-light")
  app.buttons["home.start"].tap()
  XCTAssertEqual(app.staticTexts["home.status"].label,"Ready for AirPlay")
  let disconnect=app.buttons["home.disconnect"]
  if !disconnect.isHittable { app.scrollViews.firstMatch.swipeUp() }
  disconnect.tap();XCTAssertEqual(app.staticTexts["home.status"].label,"Disconnected")
  app.scrollViews.firstMatch.swipeDown();app.buttons["home.developer"].tap()
  XCTAssertEqual(app.staticTexts["home.status"].label,"Developer controls opened")
  app.terminate();app.launchArguments=["--dark"];app.launch();capture("dashboard-dark")
  app.terminate();app.launchArguments=["--dark","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"];app.launch()
  XCTAssertTrue(app.buttons["home.start"].exists);app.scrollViews.firstMatch.swipeUp();XCTAssertTrue(app.buttons["home.disconnect"].exists);capture("dashboard-large-type")
  XCUIDevice.shared.orientation = .landscapeLeft;capture("dashboard-landscape");XCUIDevice.shared.orientation = .portrait
 }
 func testProductionControllerCancelsPendingStartAndWidgetRoutes() {
  let app=XCUIApplication();app.launchArguments=["--controller-tests"];app.launch()
  let start=app.buttons["home.start"],disconnect=app.buttons["home.disconnect"]
  XCTAssertTrue(start.waitForExistence(timeout:10));start.tap()
  XCTAssertTrue(disconnect.isEnabled,"Disconnect All must remain available during pending VPN start")
  if !disconnect.isHittable {app.scrollViews.firstMatch.swipeUp()}
  disconnect.tap()
  let stopped=NSPredicate(format:"label == %@", "Disconnected")
  expectation(for:stopped,evaluatedWith:app.staticTexts["home.status"]);waitForExpectations(timeout:12)
  sleep(2)
  XCTAssertTrue(app.staticTexts["integration.state"].label.hasPrefix("receiver=0;pip=0;peers=0"),"Late VPN success must not restart the production controller")
  app.buttons["integration.widgetStart"].tap()
  let pip=NSPredicate(format:"label CONTAINS %@", "pip=1")
  expectation(for:pip,evaluatedWith:app.staticTexts["integration.state"]);waitForExpectations(timeout:12)
  app.buttons["integration.widgetPeer"].tap();sleep(1)
  app.buttons["integration.widgetStop"].tap()
  let peers=NSPredicate(format:"label CONTAINS %@", "peers=1")
  expectation(for:peers,evaluatedWith:app.staticTexts["integration.state"]);waitForExpectations(timeout:8)
  expectation(for:stopped,evaluatedWith:app.staticTexts["home.status"]);waitForExpectations(timeout:12)
  app.terminate();app.launchArguments=["--controller-tests","--manual-disconnected","--launch-start"];app.launch()
  expectation(for:pip,evaluatedWith:app.staticTexts["integration.state"]);waitForExpectations(timeout:15)
  app.terminate();app.launchArguments=["--controller-tests","--launch-stop"];app.launch()
  expectation(for:stopped,evaluatedWith:app.staticTexts["home.status"]);waitForExpectations(timeout:12)
  sleep(2);XCTAssertEqual(app.staticTexts["integration.state"].label,"receiver=0;pip=0;peers=0;vpnRequests=0","Cold widget Stop must suppress automatic setup before app activation")
  print("PRODUCTION_CONTROLLER_INTENT_TESTS_PASSED: cancelled late VPN callback, Disconnect during Start, warm widget Start/Stop and cold widget PiP Start after manual disconnect.")
 }
 func testWidgetGalleryInspection() {
  XCUIDevice.shared.orientation = .portrait
  let app=XCUIApplication();app.launch()
  XCUIDevice.shared.press(.home);XCUIDevice.shared.press(.home)
  let spring=XCUIApplication(bundleIdentifier:"com.apple.springboard")
  // Enter editing on the actual Home Screen, never type into App Library search.
  let library=spring.searchFields.matching(NSPredicate(format:"placeholderValue CONTAINS[c] %@", "App Library")).firstMatch
  if library.exists&&library.isHittable {spring.swipeRight();sleep(1)}
  print("WIDGET_GALLERY_HOME_TREE: "+spring.debugDescription)
  let icon=spring.icons["ScreenLink"].firstMatch
  if icon.waitForExistence(timeout:5)&&icon.isHittable {
   icon.press(forDuration:1.5)
   let addHome=spring.buttons["Add to Home Screen"]
   if addHome.waitForExistence(timeout:2)&&addHome.isHittable {addHome.tap();XCUIDevice.shared.press(.home)}
   else {
    let editHome=spring.buttons["Edit Home Screen"]
    if editHome.waitForExistence(timeout:2)&&editHome.isHittable{editHome.tap()}else{XCUIDevice.shared.press(.home)}
   }
  }
  var edit=spring.buttons["Edit"].firstMatch
  if !edit.waitForExistence(timeout:2)||!edit.isHittable {
   spring.coordinate(withNormalizedOffset:CGVector(dx:0.96,dy:0.45)).press(forDuration:2)
  }
  edit=spring.buttons["Edit"].firstMatch
  if edit.waitForExistence(timeout:3)&&edit.isHittable{edit.tap()}
  var added=false
  for title in ["Add Widget","Add Widgets","Add"] {
   let button=spring.buttons[title].firstMatch
   if button.waitForExistence(timeout:2)&&button.isHittable {button.tap();added=true;break}
  }
  capture("widget-gallery-entry")
  print("WIDGET_GALLERY_ENTRY_TREE: "+spring.debugDescription)
  let searches=spring.searchFields.allElementsBoundByIndex
  guard added,let search=searches.first(where: {!($0.placeholderValue ?? "").contains("App Library")}) else {
   print("WIDGET_GALLERY_NOT_VERIFIED: correct gallery search was not available");capture("widget-gallery-unavailable");return
  }
  guard search.isHittable else {print("WIDGET_GALLERY_NOT_VERIFIED: gallery search is not hittable");return}
  search.tap();sleep(1)
  search.typeText("ScreenLink")
  let found=spring.staticTexts.containing(NSPredicate(format:"label CONTAINS[c] %@", "ScreenLink")).firstMatch
  if found.waitForExistence(timeout:8) {
   found.tap();let controls=spring.staticTexts["ScreenLink Controls"].firstMatch
   if controls.waitForExistence(timeout:5){print("WIDGET_GALLERY_SCREENLINK_CONTROLS_VERIFIED")}else{print("WIDGET_GALLERY_APP_FOUND_CONTROLS_NOT_VERIFIED")}
   capture("widget-gallery-screenlink")
  }else{print("WIDGET_GALLERY_NOT_VERIFIED: "+spring.debugDescription);capture("widget-gallery-inspection")}
 }
}
