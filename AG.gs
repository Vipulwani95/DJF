// Configuration for AG sheet
const AG_CONFIG = {
  SHEET_ID: '1a880pba8mZJS-QQVzwGUEdvXxeXCRhQa1n56htBRD8w',
  SHEET_NAME: 'App',
  TAB_NAME: 'AG'
};

// Initialize the app
function doGet(e) {
  console.log('Received GET request:', e.parameter);
  try {
    if (e.parameter.action === 'getSubscriptions') {
      return getSubscriptionsData();
    }
    return createJsonResponse({ 
      success: false,
      error: 'Invalid action',
      message: 'The requested action is not supported'
    });
  } catch (error) {
    console.error('Error in doGet:', error);
    return createJsonResponse({
      success: false,
      error: error.toString(),
      message: "Error processing request"
    });
  }
}

function doPost(e) {
  console.log('Received request:', e.postData.contents);
  try {
    var data = JSON.parse(e.postData.contents);
    console.log('Parsed data:', data);
    
    var ss = SpreadsheetApp.openById(AG_CONFIG.SHEET_ID);
    initializeAGSheet(ss);

    if (data.action === 'updateCollectionStatus') {
      return handleCollectionStatusUpdate(ss, data);
    } else if (data.action === 'reverseCollectionStatus') {
      return handleReverseCollectionStatus(data);
    }

    return createJsonResponse({
      success: false,
      message: "Invalid action specified"
    });

  } catch (error) {
    console.error('Error in doPost:', error);
    return createJsonResponse({
      success: false,
      message: "Error processing request: " + error.toString()
    });
  }
}

// Helper function to create JSON responses
function createJsonResponse(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON)
    .setHeader('Access-Control-Allow-Origin', '*')
    .setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
    .setHeader('Access-Control-Allow-Headers', 'Content-Type')
    .setHeader('Access-Control-Max-Age', '3600');
}

function initializeAGSheet(ss) {
  var sheet = ss.getSheetByName(AG_CONFIG.TAB_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(AG_CONFIG.TAB_NAME);
    sheet.appendRow([
      'MemberID', 'Name', 'Relation', 'Address', 'City', 'PinCode',
      'ContactNumber', 'Ending_Issue', 'Distributor', 'Month',
      'Status', 'Date'
    ]);
  }
  return sheet;
}

function getSubscriptionsData() {
  console.log('Fetching subscriptions data');
  try {
    var ss = SpreadsheetApp.openById(AG_CONFIG.SHEET_ID);
    var sheet = ss.getSheetByName(AG_CONFIG.TAB_NAME);
    
    if (!sheet) {
      sheet = ss.insertSheet(AG_CONFIG.TAB_NAME);
      sheet.appendRow([
        'MemberID', 'Name', 'Relation', 'Address', 'City', 'PinCode',
        'ContactNumber', 'Ending_Issue', 'Distributor', 'Month',
        'Status', 'Date'
      ]);
      return createJsonResponse({
        success: true,
        data: []
      });
    }

    var data = sheet.getDataRange().getValues();
    var headers = data[0];
    
    if (data.length <= 1) {
      return createJsonResponse({
        success: true,
        data: []
      });
    }
    
    var subscriptions = data.slice(1).map(row => {
      return {
        memberId: row[0]?.toString() || '',
        name: row[1]?.toString() || '',
        relation: row[2]?.toString() || '',
        address: row[3]?.toString() || '',
        city: row[4]?.toString() || '',
        pinCode: row[5]?.toString() || '',
        contactNumber: row[6]?.toString() || '',
        endingIssue: row[7]?.toString() || '',
        distributor: row[8]?.toString() || '',
        month: row[9]?.toString() || '',
        status: row[10]?.toString() || 'Not Collected',
        date: row[11]?.toString() || null
      };
    });
    
    console.log('Returning', subscriptions.length, 'subscriptions');
    return createJsonResponse({
      success: true,
      data: subscriptions
    });
  } catch (error) {
    console.error('Error getting subscriptions data:', error);
    return createJsonResponse({
      success: false,
      message: "Error getting subscriptions data: " + error.toString()
    });
  }
}

// Update collection status
function handleCollectionStatusUpdate(ss, data) {
  console.log('Updating collection status for:', data.memberId);
  try {
    var sheet = ss.getSheetByName(AG_CONFIG.TAB_NAME);
    
    if (!sheet) {
      return createJsonResponse({
        success: false,
        message: "AG sheet not found"
      });
    }

    var dataRange = sheet.getDataRange();
    var values = dataRange.getValues();
    
    for (var i = 1; i < values.length; i++) {
      if (values[i][0] === data.memberId && values[i][9] === data.month) {
        sheet.getRange(i + 1, 11).setValue('Collected');
        sheet.getRange(i + 1, 12).setValue(new Date().toLocaleDateString());
        
        console.log('Status updated successfully for:', data.memberId);
        return createJsonResponse({
          success: true,
          message: "Status updated successfully"
        });
      }
    }
    
    console.log('Subscription not found:', data.memberId);
    return createJsonResponse({
      success: false,
      message: "Subscription not found"
    });
  } catch (error) {
    console.error('Error updating collection status:', error);
    return createJsonResponse({
      success: false,
      message: "Error updating collection status: " + error.toString()
    });
  }
}

function handleReverseCollectionStatus(data) {
  console.log('Reversing collection status for:', data.memberId);
  try {
    var ss = SpreadsheetApp.openById(AG_CONFIG.SHEET_ID);
    var sheet = ss.getSheetByName(AG_CONFIG.TAB_NAME);
    
    if (!sheet) {
      return createJsonResponse({
        success: false,
        message: "AG sheet not found"
      });
    }

    var dataRange = sheet.getDataRange();
    var values = dataRange.getValues();
    var found = false;
    
    for (var i = 1; i < values.length; i++) {
      if (values[i][0] === data.memberId && values[i][9] === data.month) {
        // Update status and date cells
        sheet.getRange(i + 1, 11).setValue(data.status || '');  // Set status
        sheet.getRange(i + 1, 12).setValue(data.date || '');    // Set date
        found = true;
        break;
      }
    }
    
    if (found) {
      console.log('Status updated successfully for:', data.memberId);
      return createJsonResponse({
        success: true,
        message: "Status updated successfully"
      });
    } else {
      console.log('Subscription not found:', data.memberId);
      return createJsonResponse({
        success: false,
        message: "Subscription not found"
      });
    }
  } catch (error) {
    console.error('Error updating collection status:', error);
    return createJsonResponse({
      success: false,
      message: "Error updating collection status: " + error.toString()
    });
  }
} 