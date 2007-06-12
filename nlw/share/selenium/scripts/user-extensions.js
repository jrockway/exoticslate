/*
 * Get the Xpath value
 */
Selenium.prototype.getXpath = function(xpath) {
    var currentDocument = this.page().currentDocument;

    return determineXpath(xpath, currentDocument);
};

determineXpath = function(xpath, currentDocument) {
    if (browserVersion.isIE && !currentDocument.evaluate) {
        addXPathSupport(currentDocument);
    }
    if (currentDocument.evaluate) {
        return determineXpathResultUsingEvaluate(xpath, currentDocument);
    }
    // If not, fall back to slower JavaScript implementation
    return determineXpathResultUsingXPathContext(xpath, currentDocument);

};

determineXpathResultUsingXPathContext = function(xpath, currentDocument) {
    var context = new XPathContext();
    context.expressionContextNode = currentDocument;
    var xpathResult = new XPathParser().parse(xpath).evaluate(context);
    return xpathResult;
};

determineXpathResultUsingEvaluate = function(xpath, currentDocument) {
    var result = currentDocument.evaluate(xpath, currentDocument, null, XPathResult.STRING_TYPE, null);
    if (result.stringValue) {
        return result.stringValue;
    }
    return result.getStringValue();
}; 


