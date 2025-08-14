// Initialize the spreadsheet
function doGet(e) {
  try {
    return handleRequest(e);
  } catch (error) {
    console.error('Error in doGet:', error);
    return createErrorResponse(error);
  }
}

function doPost(e) {
  try {
    return handleRequest(e);
  } catch (error) {
    console.error('Error in doPost:', error);
    return createErrorResponse(error);
  }
}

function handleRequest(e) {
  try {
    console.log('Received request:', JSON.stringify(e));
    
    const action = e.parameter.action || (e.postData && JSON.parse(e.postData.contents).action);
    
    if (!action) {
      console.error('No action specified in request');
      return createResponse(false, 'No action specified');
    }
    
    console.log('Processing action:', action);
    
    switch (action) {
      case 'getSewadars':
        return getSewadars();
      case 'addSewadar':
        return addSewadar(e.postData.contents);
      case 'markAttendance':
        return markAttendance(e.postData.contents);
      case 'getAttendance':
        return getAttendance(e.parameter);
      default:
        console.error('Invalid action:', action);
        return createResponse(false, 'Invalid action: ' + action);
    }
  } catch (error) {
    console.error('Error in handleRequest:', error);
    return createErrorResponse(error);
  }
}

function getSewadars() {
  try {
    console.log('Opening spreadsheet:', SPREADSHEET_ID);
    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    console.log('Getting sheet:', SHEET_NAME);
    const sheet = ss.getSheetByName(SHEET_NAME);
    
    if (!sheet) {
      console.error('Sheet not found:', SHEET_NAME);
      return createResponse(false, 'Sheet not found: ' + SHEET_NAME);
    }
    
    const data = sheet.getDataRange().getValues();
    console.log('Retrieved data rows:', data.length);
    
    if (data.length <= 1) {
      return createResponse(true, []); // Return empty array if only headers exist
    }
    
    const headers = data[0];
    const sewadars = [];
    
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      const sewadar = {};
      headers.forEach((header, index) => {
        sewadar[header] = row[index];
      });
      sewadars.push(sewadar);
    }
    
    console.log('Retrieved ' + sewadars.length + ' sewadars');
    return createResponse(true, sewadars);
  } catch (error) {
    console.error('Error in getSewadars:', error);
    return createErrorResponse(error);
  }
}

function addSewadar(postData) {
  try {
    console.log('Adding new sewadar:', postData);
    const sewadar = JSON.parse(postData).sewadar;
    const sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_NAME);
    
    // Add new row
    sheet.appendRow([
      sewadar.id,
      sewadar.name,
      sewadar.phone,
      sewadar.address,
      sewadar.photoUrl,
      sewadar.qrCode,
      sewadar.joinDate,
      sewadar.designation
    ]);
    
    console.log('Sewadar added successfully');
    return createResponse(true, 'Sewadar added successfully');
  } catch (error) {
    console.error('Error in addSewadar:', error);
    return createErrorResponse(error);
  }
}

function markAttendance(postData) {
  try {
    console.log('Marking attendance:', postData);
    const data = JSON.parse(postData);
    const sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(ATTENDANCE_SHEET_NAME);
    
    // Check if attendance already marked for today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const attendanceData = sheet.getDataRange().getValues();
    for (let i = 1; i < attendanceData.length; i++) {
      const row = attendanceData[i];
      const rowDate = new Date(row[1]);
      rowDate.setHours(0, 0, 0, 0);
      
      if (row[0] === data.sewadarId && rowDate.getTime() === today.getTime()) {
        console.log('Attendance already marked for today');
        return createResponse(false, 'Attendance already marked for today');
      }
    }
    
    // Add attendance record
    sheet.appendRow([
      data.sewadarId,
      new Date(data.date),
      new Date(), // Timestamp
      data.status || 'Present' // Status (Present, Absent, Late)
    ]);
    
    console.log('Attendance marked successfully');
    return createResponse(true, 'Attendance marked successfully');
  } catch (error) {
    console.error('Error in markAttendance:', error);
    return createErrorResponse(error);
  }
}

function getAttendance(params) {
  try {
    console.log('Getting attendance with params:', JSON.stringify(params));
    const sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(ATTENDANCE_SHEET_NAME);
    const data = sheet.getDataRange().getValues();
    const headers = data[0];
    
    let filteredData = data.slice(1); // Remove headers
    
    // Filter by date range if provided
    if (params.startDate && params.endDate) {
      const startDate = new Date(params.startDate);
      const endDate = new Date(params.endDate);
      startDate.setHours(0, 0, 0, 0);
      endDate.setHours(23, 59, 59, 999);
      
      filteredData = filteredData.filter(row => {
        const rowDate = new Date(row[1]);
        return rowDate >= startDate && rowDate <= endDate;
      });
    }
    
    // Filter by sewadar ID if provided
    if (params.sewadarId) {
      filteredData = filteredData.filter(row => row[0] === params.sewadarId);
    }
    
    const attendance = filteredData.map(row => {
      const record = {};
      headers.forEach((header, index) => {
        record[header] = row[index];
      });
      return record;
    });
    
    console.log('Retrieved ' + attendance.length + ' attendance records');
    return createResponse(true, attendance);
  } catch (error) {
    console.error('Error in getAttendance:', error);
    return createErrorResponse(error);
  }
}

function createResponse(success, data) {
  return ContentService.createTextOutput(JSON.stringify({
    success: success,
    data: data
  })).setMimeType(ContentService.MimeType.JSON);
}

function createErrorResponse(error) {
  return ContentService.createTextOutput(JSON.stringify({
    success: false,
    error: error.toString(),
    message: 'An error occurred while processing your request'
  })).setMimeType(ContentService.MimeType.JSON);
}

// Helper function to create the initial spreadsheet structure
function createInitialStructure() {
  try {
    console.log('Creating initial spreadsheet structure');
    const ss = SpreadsheetApp.create('QR Attendance System');
    const sewadarsSheet = ss.getActiveSheet();
    sewadarsSheet.setName(SHEET_NAME);
    
    // Set headers for Sewadars sheet
    sewadarsSheet.getRange('A1:H1').setValues([['id', 'name', 'phone', 'address', 'photoUrl', 'qrCode', 'joinDate', 'designation']]);
    
    // Create Attendance sheet
    const attendanceSheet = ss.insertSheet(ATTENDANCE_SHEET_NAME);
    attendanceSheet.getRange('A1:D1').setValues([['sewadarId', 'date', 'timestamp', 'status']]);
    
    // Format headers
    [sewadarsSheet, attendanceSheet].forEach(sheet => {
      sheet.getRange('1:1').setFontWeight('bold');
      sheet.setFrozenRows(1);
    });
    
    console.log('Initial structure created successfully');
    return ss.getId();
  } catch (error) {
    console.error('Error in createInitialStructure:', error);
    throw error;
  }
} 