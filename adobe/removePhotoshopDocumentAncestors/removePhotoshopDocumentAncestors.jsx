// https://forums.adobe.com/message/8511978#8511978
function deleteDocumentAncestorsMetadata() {
  var whatApp = String(app.name);
  if (whatApp.search('Photoshop') > 0) {
    if (!documents.length) {
      return;
    }
    try {
      if (ExternalObject.AdobeXMPScript == undefined) {
        ExternalObject.AdobeXMPScript = new ExternalObject('lib:AdobeXMPScript');
      }
      var xmp = new XMPMeta(activeDocument.xmpMetadata.rawData);

      if (xmp.doesPropertyExist(XMPConst.NS_PHOTOSHOP, 'DocumentAncestors')) {
        xmp.deleteProperty(XMPConst.NS_PHOTOSHOP, 'DocumentAncestors');
        app.activeDocument.xmpMetadata.rawData = xmp.serialize();
      }
    } catch (e) {
      // 保存処理を妨げない
    }
  }
}
deleteDocumentAncestorsMetadata();