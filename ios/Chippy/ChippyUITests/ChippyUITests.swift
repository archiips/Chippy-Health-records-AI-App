import XCTest

final class ChippyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testSyntheticPhotoReviewAndExport() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHIPPY_SYNTHETIC_PHOTO"] == "1",
            "Seed a dedicated simulator with only the synthetic lab image and opt in to this photo-picker test.")
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-faceIDEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 15))
        app.buttons["Add Photo"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "Synthetic photo-picker fixture"
        picker.lifetime = .keepAlways
        add(picker)
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForNonExistence(timeout: 15))
        let marker = "Photo E2E " + UUID().uuidString.prefix(8)
        // Only a newly completed import navigates here; an older list row cannot satisfy this check.
        XCTAssertTrue(app.buttons["Read Page Text"].waitForExistence(timeout: 20))
        app.buttons["Record Details"].tap()
        let nameField = app.textFields["Record name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap(); nameField.typeText(" " + marker)
        XCTAssertTrue((nameField.value as? String)?.contains(marker) == true)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Read Page Text"].waitForExistence(timeout: 5))
        app.buttons["Read Page Text"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "SYNTHETIC RECORD")).firstMatch.exists)
        app.buttons["Read Page Text"].tap()
        scrollTo(app.buttons["Add Fact from Original"], in: app)
        app.buttons["Add Fact from Original"].tap()
        XCTAssertTrue(app.navigationBars["Review Fact"].waitForExistence(timeout: 5))
        let multilineQuote = app.textViews["fact-source-quote"]
        let quote = multilineQuote.exists ? multilineQuote : app.textFields["fact-source-quote"]
        quote.tap(); quote.typeText("Collected: 2026-09-18\nGlucose 105 mg/dL 70-100")
        let category = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Category")).firstMatch
        scrollTo(category, in: app)
        category.tap()
        app.buttons["Lab"].tap()
        app.textFields["Name"].tap(); app.textFields["Name"].typeText("Glucose")
        app.textFields["Value as recorded"].tap(); app.textFields["Value as recorded"].typeText("105")
        app.textFields["Unit, if recorded"].tap(); app.textFields["Unit, if recorded"].typeText("mg/dL")
        app.textFields["Reference range, if recorded"].tap(); app.textFields["Reference range, if recorded"].typeText("70-100")
        app.textFields["Date as recorded (YYYY-MM-DD if known)"].tap(); app.textFields["Date as recorded (YYYY-MM-DD if known)"].typeText("2026-09-18")
        app.swipeUp()
        let checked = app.switches["I checked these fields against the original page"]
        checked.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["Save Reviewed Fact"].isEnabled)
        app.buttons["Save Reviewed Fact"].tap()
        let reviewed = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Reviewed by you")).firstMatch
        scrollTo(reviewed, in: app)
        XCTAssertTrue(reviewed.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Synthetic source and reviewed fact"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Timeline"].tap()
        XCTAssertTrue(app.staticTexts["September 2026"].waitForExistence(timeout: 5))
        let importedEvent = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        scrollTo(importedEvent, in: app)
        XCTAssertTrue(importedEvent.exists)
        snapshot(app, name: "Photographed medical record timeline")
        for _ in 0..<10 where !app.buttons["Lab Trends"].isHittable { app.swipeDown() }
        app.buttons["Lab Trends"].tap()
        XCTAssertTrue(app.navigationBars["Lab Trends"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.tabBars.buttons["Chat"].tap()
        app.buttons["Choose chat records"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch.tap()
        let input = app.textFields["local-chat-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        sendChat("When was my last lab work?", expecting: "From the facts you reviewed", in: app)
        let sources = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "[1]", marker))
        XCTAssertTrue(sources.firstMatch.waitForExistence(timeout: 5))
        let source = try XCTUnwrap(sources.allElementsBoundByIndex.last(where: \.isHittable))
        snapshot(app, name: "Local chat answer and page citation")
        source.tap()
        XCTAssertTrue(app.buttons["Open Original Page"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        sendChat("Show me my test results", expecting: "Glucose: 105", in: app)
        sendChat("What about that result?", expecting: "105", in: app)
        sendChat("Are my labs normal?", expecting: "cannot determine", in: app)
        snapshot(app, name: "Record chat answers common questions")
        app.tabBars.buttons["Timeline"].tap()
        app.buttons["Export"].tap()
        XCTAssertTrue(app.navigationBars["Appointment Summary"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Share Selected Facts"].exists)
        let importedFact = app.switches.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        scrollTo(importedFact, in: app)
        XCTAssertTrue(importedFact.exists)
        let control = importedFact.switches.firstMatch
        if control.exists { control.tap() } else { importedFact.tap() }
        app.buttons["review-selected-facts"].tap()
        XCTAssertTrue(app.buttons["Share Selected Facts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch.exists)
        let export = XCTAttachment(screenshot: app.screenshot())
        export.name = "Selected reviewed export preview"
        export.lifetime = .keepAlways
        add(export)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 10))
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText(marker)
        let savedRecord = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        XCTAssertTrue(savedRecord.waitForExistence(timeout: 5))
        savedRecord.tap()
        let savedFact = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Reviewed by you")).firstMatch
        scrollTo(savedFact, in: app)
        XCTAssertTrue(savedFact.exists)
        snapshot(app, name: "Imported photo and reviewed fact survive relaunch")
    }

    @MainActor
    func testRestoredScreensAndLibraryFilters() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-faceIDEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 15))
        snapshot(app, name: "Restored medical document library")
        app.buttons["Filter Records"].tap()
        XCTAssertTrue(app.buttons["All Document Types"].waitForExistence(timeout: 5))
        app.buttons["All Document Types"].tap()
        app.tabBars.buttons["Timeline"].tap()
        XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 5))
        snapshot(app, name: "Restored medical timeline")
        app.tabBars.buttons["Chat"].tap()
        XCTAssertTrue(app.navigationBars["Chat"].waitForExistence(timeout: 5))
        snapshot(app, name: "Restored record chat")
    }

    @MainActor
    func testPhotoEntryAndCancellationDoNotTriggerAnotherImportSource() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-faceIDEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Take a Scan"].isEnabled)
        app.buttons["Add Photo"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Photo"].isHittable)
        let importRow = app.cells.containing(.button, identifier: "Add Photo").firstMatch
        XCTAssertTrue(importRow.exists)
        importRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(app.navigationBars["Photos"].waitForExistence(timeout: 3), "Space between separate buttons must not activate photo import")
        app.buttons["Import"].tap()
        app.buttons["Import Photo"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForNonExistence(timeout: 5))
        app.buttons["Import"].tap()
        app.buttons["Import PDF"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Add Photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.allElementsBoundByIndex.isEmpty)
        snapshot(app, name: "Independent import sources after cancellation")
    }

    @MainActor
    func testChatHelpAndCommonQuestionWording() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-faceIDEnabled", "NO"]
        app.launch()
        app.tabBars.buttons["Chat"].tap()
        XCTAssertTrue(app.staticTexts["Offline record lookup"].waitForExistence(timeout: 5))
        app.buttons["How Chat Works"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "This simulator uses offline record lookup")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["How Chat Works"].tap()
        sendChat("Hello Chippy", expecting: "Hi!", in: app)
        XCTAssertTrue(app.buttons["Summary"].exists)
        sendChat("How does this work?", expecting: "original pages", in: app)
        snapshot(app, name: "Guided local chat and useful help")
    }

    @MainActor
    private func sendChat(_ question: String, expecting text: String, in app: XCUIApplication) {
        let replies = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "local-assistant-message-"))
        let previousID = replies.allElementsBoundByIndex.last?.identifier
        let input = app.textFields["local-chat-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText(question)
        app.buttons["Send"].tap()
        let newReply = NSPredicate { _, _ in
            guard let last = replies.allElementsBoundByIndex.last else { return false }
            return last.identifier != previousID && last.label.contains(text)
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: newReply, object: app)], timeout: 10), .completed)
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLocalWorkflowWithoutLoginAndCloudConsentCanBeCancelled() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-faceIDEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.textFields["Email"].exists)
        app.tabBars.buttons["Timeline"].tap()
        XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Chat"].tap()
        XCTAssertTrue(app.navigationBars["Chat"].exists)
        app.tabBars.buttons["Records"].tap()
        app.buttons["Search Pages"].tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Use Cloud Mode…"].tap()
        XCTAssertTrue(app.navigationBars["Cloud Data Permission"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Allow Cloud Processing and Continue"].exists)
        app.buttons["Keep Using This Device"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Cloud Data Permission"].exists)
        XCTAssertTrue(app.buttons["Use Cloud Mode…"].exists)
        app.buttons["Delete Local Records…"].tap()
        XCTAssertTrue(app.alerts["Delete all local records?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Local settings and privacy boundary"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
