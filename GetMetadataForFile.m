#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#import "Cocoa/Cocoa.h"
#import "GNJUnZip.h"

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports

   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes
   that your importer can handle

   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2
   Implement the GetMetadataForURL function

   Implement the GetMetadataForURL function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional)
   If you have defined new attributes, update schema.xml and schema.strings files

   The schema.xml should be added whenever you need attributes displayed in
   Finder's get info panel, or when you have custom attributes.
   The schema.strings should be added whenever you have custom attributes.

   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.

   Add any custom types that your importer requires to the <attributes> element

   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>

   ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
   Get metadata attributes from file

   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */

Boolean GetMetadataForURL(void* thisInterface,
                          CFMutableDictionaryRef attributes,
                          CFStringRef contentTypeUTI,
                          CFURLRef urlForFile)
{
  /* Pull any available metadata from the file at the specified path */
  /* Return the attribute keys and attribute values in the dict */
  /* Return TRUE if successful, FALSE if there was no data provided */

  @autoreleasepool {

		NSMutableDictionary *NSAttribs = (__bridge NSMutableDictionary *)attributes;
		
  NSCharacterSet *setForTrim = [NSCharacterSet whitespaceAndNewlineCharacterSet];

  NSString *path = [(__bridge NSURL *)urlForFile path];
  GNJUnZip *unzip = [[GNJUnZip alloc] initWithZipFile:path];

  NSData *xmlData = [unzip dataWithContentsOfFile:@"META-INF/container.xml"];
  if(!xmlData) {
    return FALSE;
  }
  NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithData:xmlData
                                                      options:NSXMLDocumentTidyXML
                                                        error:NULL];
  if(!xmlDoc) {
    return FALSE;
  }
  NSString *xpath = @"/container/rootfiles/rootfile/@full-path";
  NSArray *nodes = [xmlDoc nodesForXPath:xpath error:NULL];
  if(![nodes count]) {
    NSLog(@"no such nodes for xpath '%@'", xpath);
    return FALSE;
  }
  NSXMLNode *fullPathNode = nodes[0];
  NSString *fullPathValue = [fullPathNode stringValue];
  NSString *opfPath = [fullPathValue stringByTrimmingCharactersInSet:setForTrim];
  opfPath = [opfPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  xmlData = [unzip dataWithContentsOfFile:opfPath];
  if(!xmlDoc) {
    return FALSE;
  }
  xmlDoc = [[NSXMLDocument alloc] initWithData:xmlData
                                       options:NSXMLDocumentTidyXML
                                         error:NULL];
  if(!xmlDoc) {
    return FALSE;
  }
  xpath = @"/package/metadata/*";
  nodes = [xmlDoc nodesForXPath:xpath error:NULL];
  if(![nodes count]) {
    NSLog(@"no such nodes for xpath '%@'", xpath);
    return FALSE;
  }

  NSMutableArray *titles = [NSMutableArray array];
  NSMutableArray *authors = [NSMutableArray array];
  NSMutableArray *subjects = [NSMutableArray array];
  NSString *description = nil;
  NSMutableArray *publishers = [NSMutableArray array];
  NSMutableArray *contributors = [NSMutableArray array];
  NSMutableArray *identifiers = [NSMutableArray array];
  NSMutableArray *languages = [NSMutableArray array];
  NSString *coverage = nil;
  NSString *copyright = nil;

  for(NSXMLNode *node in nodes) {
    NSString *nodeName = [node name];
    if([nodeName isEqualToString:@"dc:title"]) {
      [titles addObject:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:creator"]) {
      [authors addObject:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:subject"]) {
      [subjects addObject:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:description"]) {
      description = [NSString stringWithString:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:publisher"]) {
      [publishers addObject:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:contributor"]) {
      [contributors addObject:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:identifier"]) {
      [identifiers addObject:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:language"]) {
      [languages addObject:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:coverage"]) {
      coverage = [NSString stringWithString:[node stringValue]];
    }
    else if([nodeName isEqualToString:@"dc:rights"]) {
      copyright = [NSString stringWithString:[node stringValue]];
    }
  }

  NSMutableArray *bodies = [NSMutableArray array];
  xpath = @"/package/manifest/item";
  nodes = [xmlDoc nodesForXPath:xpath error:NULL];
  if(![nodes count]) {
    NSLog(@"no such nodes for xpath '%@'", xpath);
    return FALSE;
  }
  NSMutableDictionary *manifest = [NSMutableDictionary dictionary];
  for(NSXMLElement *elem in nodes) {
    NSXMLNode *idNode = [elem attributeForName:@"id"];
    NSXMLNode *hrefNode = [elem attributeForName:@"href"];
    NSString *key = [[idNode stringValue] stringByTrimmingCharactersInSet:setForTrim];
    NSString *path = [[hrefNode stringValue] stringByTrimmingCharactersInSet:setForTrim];
    path = [path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    manifest[key] = path;
  }
  xpath = @"/package/spine/itemref/@idref";
  nodes = [xmlDoc nodesForXPath:xpath error:NULL];
  if(![nodes count]) {
    NSLog(@"no such nodes for xpath '%@'", xpath);
    return FALSE;
  }
  NSString *opfBasePath = [opfPath stringByDeletingLastPathComponent];
  for(NSXMLNode *node in nodes) {
    NSString *idrefValue = [[node stringValue] stringByTrimmingCharactersInSet:setForTrim];
    NSString *hrefValue = manifest[idrefValue];
    if(![hrefValue length]) continue;
    NSString *path = nil;
    if([hrefValue isAbsolutePath]) path = [hrefValue substringFromIndex:1];
    else path = [opfBasePath stringByAppendingPathComponent:hrefValue];
    NSData *htmlData = [unzip dataWithContentsOfFile:path];
    if(htmlData) {
      NSXMLDocument *htmlDoc;
      htmlDoc = [[NSXMLDocument alloc] initWithData:htmlData
                                            options:NSXMLDocumentTidyXML
                                              error:NULL];
      if(htmlDoc) {
        NSArray *nodes = [htmlDoc nodesForXPath:@"/html" error:NULL];
        if([nodes count]) {
          NSXMLNode *bodyNode = nodes[0];
          NSString *bodyString = [bodyNode stringValue];
          [bodies addObject:bodyString];
        }
      }
    }
  }

  if([titles count]) {
    NSString *titleString = [titles componentsJoinedByString:@", "];
    NSAttribs[(NSString *)kMDItemTitle] = titleString;
  }
  if([authors count]) {
    NSAttribs[(NSString *)kMDItemAuthors] = authors;
  }
  if([subjects count]) {
    NSAttribs[(NSString *)kMDItemKeywords] = subjects;
  }
  if([description length]) {
    NSAttribs[(NSString *)kMDItemDescription] = description;
    NSAttribs[(NSString *)kMDItemHeadline] = description;
  }
  if([publishers count]) {
    NSAttribs[(NSString *)kMDItemPublishers] = publishers;
    NSAttribs[(NSString *)kMDItemOrganizations] = publishers;
  }
  if([contributors count]) {
    NSAttribs[(NSString *)kMDItemContributors] = contributors;
  }
  if([identifiers count]) {
    NSString *idString = [identifiers componentsJoinedByString:@", "];
    NSAttribs[(NSString *)kMDItemIdentifier] = idString;
  }
  if([languages count]) {
    NSAttribs[(NSString *)kMDItemLanguages] = languages;
  }
  if([coverage length]) {
    NSAttribs[(NSString *)kMDItemCoverage] = coverage;
  }
  if([copyright length]) {
    NSAttribs[(NSString *)kMDItemCopyright] = copyright;
    NSAttribs[(NSString *)kMDItemRights] = copyright;
  }
  if([bodies count]) {
    NSString *bodyString = [bodies componentsJoinedByString:@" "];
    NSAttribs[(NSString *)kMDItemTextContent] = bodyString;

    NSAttribs[(NSString *)kMDItemNumberOfPages] = @([bodies count]);
  }

  }

  return TRUE;
}
