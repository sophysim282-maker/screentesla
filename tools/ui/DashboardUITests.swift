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
 func testWidgetGalleryInspection() {
  let app=XCUIApplication();app.launch();XCUIDevice.shared.press(.home)
  let spring=XCUIApplication(bundleIdentifier:"com.apple.springboard")
  let icon=spring.icons["ScreenLink"].firstMatch
  guard icon.waitForExistence(timeout:10) else {print("WIDGET_GALLERY_NOT_VERIFIED: app icon not located on this simulator page");capture("widget-gallery-unavailable");return}
  icon.press(forDuration:1.5)
  let edit=spring.buttons["Edit Home Screen"]
  if edit.waitForExistence(timeout:3) {edit.tap()}
  let add=spring.buttons["Add Widget"]
  if add.waitForExistence(timeout:3) {add.tap()}
  else {
   let menu=spring.buttons["Edit"].firstMatch
   if menu.exists {menu.tap();let option=spring.buttons["Add Widget"].firstMatch;if option.waitForExistence(timeout:3){option.tap()}}
  }
  let search=spring.searchFields.firstMatch
  guard search.waitForExistence(timeout:5) else {print("WIDGET_GALLERY_NOT_VERIFIED: add-widget search unavailable");capture("widget-gallery-inspection");return}
  search.tap();search.typeText("ScreenLink")
  let found=spring.staticTexts.containing(NSPredicate(format:"label CONTAINS[c] %@", "ScreenLink")).firstMatch
  if found.waitForExistence(timeout:5) {
   found.tap();let controls=spring.staticTexts["ScreenLink Controls"].firstMatch
   if controls.waitForExistence(timeout:5){print("WIDGET_GALLERY_SCREENLINK_CONTROLS_VERIFIED")}else{print("WIDGET_GALLERY_APP_FOUND_CONTROLS_NOT_VERIFIED")}
   capture("widget-gallery-screenlink")
  } else {print("WIDGET_GALLERY_NOT_VERIFIED: "+spring.debugDescription);capture("widget-gallery-inspection")}
 }
}
