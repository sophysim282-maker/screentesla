import XCTest
final class DashboardUITests: XCTestCase {
 func snap(_ n:String){let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=n;a.lifetime = .keepAlways;add(a)}
 func testWidgetGalleryInspection(){
  let app=XCUIApplication();app.launch();sleep(3);XCUIDevice.shared.press(.home);sleep(2)
  let s=XCUIApplication(bundleIdentifier:"com.apple.springboard")
  print("HOME: "+s.debugDescription)
  let icon=s.icons["Calendar"].firstMatch
  if !icon.isHittable{s.swipeRight();sleep(1)}
  XCTAssertTrue(icon.isHittable);icon.press(forDuration:2);sleep(1)
  print("CONTEXT: "+s.debugDescription);snap("context")
  let editHome=s.buttons["Edit Home Screen"].firstMatch
  XCTAssertTrue(editHome.waitForExistence(timeout:5));editHome.tap();sleep(2)
  print("EDIT: "+s.debugDescription);snap("edit")
  let edit=s.buttons["Edit"].firstMatch
  if edit.waitForExistence(timeout:3){edit.tap();sleep(1)}
  print("MENU: "+s.debugDescription)
  let add=s.buttons.matching(NSPredicate(format:"label == %@ OR label == %@ OR label == %@", "Add Widget","Add Widgets","Add")).firstMatch
  XCTAssertTrue(add.waitForExistence(timeout:5));add.tap();sleep(3)
  print("GALLERY: "+s.debugDescription);snap("gallery")
  let search=s.searchFields.firstMatch
  XCTAssertTrue(search.waitForExistence(timeout:5));XCTAssertFalse((search.placeholderValue ?? "").contains("App Library"))
  search.tap();search.typeText("ScreenLink");sleep(5)
  print("SEARCH: "+s.debugDescription);snap("search")
  let result=s.staticTexts["ScreenLink"].firstMatch
  XCTAssertTrue(result.waitForExistence(timeout:10),"Must register in real WidgetKit gallery");result.tap();sleep(4)
  print("CONFIGURATION: "+s.debugDescription);snap("configuration")
  XCTAssertTrue(s.staticTexts["ScreenLink Controls"].waitForExistence(timeout:5))
  let addWidget=s.buttons["Add Widget"].firstMatch
  XCTAssertTrue(addWidget.waitForExistence(timeout:5));addWidget.tap();sleep(5)
  if s.buttons["Done"].firstMatch.isHittable{s.buttons["Done"].firstMatch.tap()}
  print("INSTALLED: "+s.debugDescription);snap("installed")
  XCTAssertTrue(s.staticTexts["A bigger view"].exists || s.staticTexts["Open controls"].exists)
  print("ACTUAL_WIDGET_GALLERY_AND_RENDER_VERIFIED")
 }
}
