// https://forums.adobe.com/message/8511978#8511978
function deleteDocumentAncestorsMetadataWithSave() {
  var whatApp = String(app.name); //String version of the app name
  if (whatApp.search('Photoshop') > 0) {
    //Check for photoshop specifically, or this will cause errors
    //Function Scrubs Document Ancestors from Files
    if (!documents.length) {
      return;
    }
    if (ExternalObject.AdobeXMPScript == undefined) {
      ExternalObject.AdobeXMPScript = new ExternalObject('lib:AdobeXMPScript');
    }
    var xmp = new XMPMeta(activeDocument.xmpMetadata.rawData);
    // Begone foul Document Ancestors!
    xmp.deleteProperty(XMPConst.NS_PHOTOSHOP, 'DocumentAncestors');
    app.activeDocument.xmpMetadata.rawData = xmp.serialize();
    app.activeDocument.save();
  }
}
//Now run the function to remove the document ancestors
deleteDocumentAncestorsMetadataWithSave();
