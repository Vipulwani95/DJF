// Removed duplicate minimal doPost; consolidated below in router doPost

// Provide qty summary as a reusable function instead of a dedicated doGet implementation
function getQtySummary() {
  try {
    var sheet = SpreadsheetApp.openById(CONFIG.SHEET_ID).getSheetByName('Inventory');
    var range = sheet.getDataRange();
    var values = range.getValues();

    var headers = values[0];
    var qtyColIndex = headers.indexOf('Qty');
    var idColIndex = headers.indexOf('S.No');

    if (qtyColIndex === -1 || idColIndex === -1) {
      return ContentService.createTextOutput(JSON.stringify({
        success: false,
        message: 'Required columns not found'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var qtyData = [];
    for (var i = 1; i < values.length; i++) {
      qtyData.push({ id: values[i][idColIndex], qty: values[i][qtyColIndex] });
    }

    return ContentService.createTextOutput(JSON.stringify({
      success: true,
      data: qtyData
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function handleLogin(sheet, data) {
  console.log('Processing login (permissive) for:', data && data.Login);
  // Accept any credentials; mark admin role if username is 'admin'
  var uname = (data && data.Login) ? String(data.Login) : '';
  var role = uname.toLowerCase() === 'admin' ? 'admin' : 'user';
  return ContentService.createTextOutput(JSON.stringify({
    success: true,
    message: "Login successful",
    username: uname,
    role: role
  })).setMimeType(ContentService.MimeType.JSON);
}

// Removed duplicate 'GET not supported' doGet; consolidated router doGet remains

function doGet(e) {
  console.log('Received GET request:', e.parameter);
  try {
    if (e.parameter.action === 'getInventory') {
      return getInventoryData();
    }
    if (e.parameter.action === 'getOrders' && e.parameter.username) {
      return getOrdersData(e.parameter.username);
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
    
    var ss = SpreadsheetApp.openById(CONFIG.SHEET_ID);
    initializeSheets(ss);

    if (data.action === 'submitOrder') {
      return handleOrderSubmission(ss, data);
    } else if (data.action === 'deleteOrder') {
      return handleOrderDeletion(ss, data);
    } else if (data.action === 'login') {
      return handleLogin(ss, data);
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

function createJsonResponse(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

function initializeSheets(ss) {
  var requiredSheets = ["Users", "Inventory", "Orders", "Tally"];
  var existingSheets = ss.getSheets().map(sheet => sheet.getName());
  
  requiredSheets.forEach(sheetName => {
    if (!existingSheets.includes(sheetName)) {
      var newSheet = ss.insertSheet(sheetName);
      if (sheetName === "Users") {
        newSheet.appendRow(["Login", "Password"]);
      } else if (sheetName === "Inventory") {
        // Match provided headers and order exactly
        newSheet.appendRow(["S.No", "Particulars", "Tax", "Qty", "HSN", "Bal", "Sale", "Rate", "Amount", "category"]);
      } else if (sheetName === "Orders") {
        // Match provided headers and order exactly (Items before Status)
        newSheet.appendRow(["Order ID", "Date", "Username", "Total Amount", "Payment Method", "Cash Handler", "Items", "Status"]);
      } else if (sheetName === "Tally") {
        newSheet.appendRow(["Payment Type", "Date", "Percent", "Invoice", "Items", "HSN", "Qty", "Rate", "Amount", "Discount", "Cash Handler"]);
      }
    }
  });
}

function handleOrderSubmission(ss, data) {
  console.log('Starting order submission');
  var ordersSheet = ss.getSheetByName("Orders");
  var orderId = "ORD" + new Date().getTime().toString().slice(-6) + Math.floor(Math.random() * 1000);
  var itemsJson = JSON.stringify(data.items);

  // Append in exact header order: Order ID, Date, Username, Total Amount, Payment Method,
  // Cash Handler, Items, Status
  ordersSheet.appendRow([
    orderId,
    data.date,
    data.username,
    data.totalAmount,
    data.paymentMethod || "",
    data.cashHandler || "",
    itemsJson,
    "Completed"
  ]);

  updateInventoryAndTally(ss, data, orderId); // Use orderId in Tally

  return ContentService.createTextOutput(JSON.stringify({
    success: true,
    message: "Order submitted successfully",
    orderId: orderId
  })).setMimeType(ContentService.MimeType.JSON);
}

function updateInventoryAndTally(ss, data, orderId) {
  console.log('Updating inventory and tally for order ID:', orderId);
  var inventorySheet = ss.getSheetByName("Inventory");
  var tallySheet = ss.getSheetByName("Tally");

  var inventoryData = inventorySheet.getDataRange().getValues();
  var headers = inventoryData[0];
  var nameIndex = headers.indexOf("Particulars");
  var taxIndex = headers.indexOf("Tax");
  var hsnIndex = headers.indexOf("HSN");
  var rateIndex = headers.indexOf("Rate");
  var balIndex = headers.indexOf("Bal");

  data.items.forEach(orderItem => {
    for (var i = 1; i < inventoryData.length; i++) {
      if (inventoryData[i][nameIndex] === orderItem.name) {
        var currentBal = parseInt(inventoryData[i][balIndex]) || 0;
        // On order placement, only reduce Bal (stock). Qty remains as opening balance.
        inventorySheet.getRange(i + 1, balIndex + 1).setValue(currentBal - orderItem.quantity);

        tallySheet.appendRow([
          data.paymentMethod || "",
          data.date,
          inventoryData[i][taxIndex] || "0%",
          orderId,
          orderItem.name,
          inventoryData[i][hsnIndex] || "",
          orderItem.quantity,
          inventoryData[i][rateIndex] || 0,
          orderItem.total,
          "0%",
          data.cashHandler || ""
        ]);
        break;
      }
    }
  });
}

function handleOrderDeletion(ss, data) {
  console.log('Starting order deletion for:', data.invoiceNumber);
  var ordersSheet = ss.getSheetByName("Orders");
  var tallySheet = ss.getSheetByName("Tally");
  var inventorySheet = ss.getSheetByName("Inventory");

  var ordersData = ordersSheet.getDataRange().getValues();
  var tallyData = tallySheet.getDataRange().getValues();
  var inventoryData = inventorySheet.getDataRange().getValues();

  var orderIdIndex = ordersData[0].indexOf("Order ID");
  var itemsIndex = ordersData[0].indexOf("Items");
  var invoiceIndex = tallyData[0].indexOf("Invoice");
  var itemIndex = tallyData[0].indexOf("Items");
  var qtyIndex = tallyData[0].indexOf("Qty");
  var pIndex = inventoryData[0].indexOf("Particulars");
  var bIndex = inventoryData[0].indexOf("Bal");

  var orderRow = -1;
  for (var i = 1; i < ordersData.length; i++) {
    if (ordersData[i][orderIdIndex] === data.invoiceNumber) {
      orderRow = i;
      break;
    }
  }

  if (orderRow !== -1) ordersSheet.deleteRow(orderRow + 1);

  var rowsToDelete = [];
  for (var i = 1; i < tallyData.length; i++) {
    if (tallyData[i][invoiceIndex] === data.invoiceNumber) {
      rowsToDelete.push(i + 1);
      var item = tallyData[i][itemIndex];
      var qty = tallyData[i][qtyIndex];
      for (var j = 1; j < inventoryData.length; j++) {
        if (inventoryData[j][pIndex] === item) {
          var currBal = parseInt(inventoryData[j][bIndex]) || 0;
          inventorySheet.getRange(j + 1, bIndex + 1).setValue(currBal + qty);
          break;
        }
      }
    }
  }

  rowsToDelete.reverse().forEach(row => tallySheet.deleteRow(row));

  return createJsonResponse({
    success: true,
    message: "Order deleted successfully"
  });
}

function handleLogin(ss, data) {
  // Accept any credentials; mark admin role if username is 'admin'
  var uname = (data && data.Login) ? String(data.Login) : '';
  var role = uname.toLowerCase() === 'admin' ? 'admin' : 'user';
  return createJsonResponse({
    success: true,
    message: "Login successful",
    username: uname,
    role: role
  });
}

function getInventoryData() {
  try {
    var ss = SpreadsheetApp.openById(CONFIG.SHEET_ID);
    var sheet = ss.getSheetByName("Inventory");
    if (!sheet) {
      return ContentService.createTextOutput(JSON.stringify([]))
        .setMimeType(ContentService.MimeType.JSON);
    }
    var data = sheet.getDataRange().getValues();
    if (!data || data.length === 0) {
      return ContentService.createTextOutput(JSON.stringify([]))
        .setMimeType(ContentService.MimeType.JSON);
    }
    var headers = data[0];
    var json = [];

    for (var i = 1; i < data.length; i++) {
      var row = {};
      for (var j = 0; j < headers.length; j++) {
        row[headers[j]] = data[i][j];
      }
      json.push(row);
    }

    return ContentService.createTextOutput(JSON.stringify(json))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    console.error('getInventoryData error:', error && error.toString ? error.toString() : error);
    // Keep response shape consistent for client parsing
    return ContentService.createTextOutput(JSON.stringify([]))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function getOrdersData(username) {
  try {
    var ss = SpreadsheetApp.openById(CONFIG.SHEET_ID);
    var sheet = ss.getSheetByName("Orders");
    if (!sheet) {
      // Keep response shape as array for client compatibility
      return ContentService.createTextOutput(JSON.stringify([]))
        .setMimeType(ContentService.MimeType.JSON);
    }
    var data = sheet.getDataRange().getValues();
    if (!data || data.length === 0) {
      return ContentService.createTextOutput(JSON.stringify([]))
        .setMimeType(ContentService.MimeType.JSON);
    }
    var headers = data[0];
    var orders = [];
    
    function norm(s) { return String(s || '').trim().toLowerCase().replace(/\s+/g, ' '); }
    function normCompact(s) { return String(s || '').trim().toLowerCase().replace(/\s+/g, ''); }
    function findIndex(names) {
      for (var i = 0; i < headers.length; i++) {
        var h = headers[i];
        var hn = norm(h);
        var hc = normCompact(h);
        for (var j = 0; j < names.length; j++) {
          var nn = norm(names[j]);
          var nc = normCompact(names[j]);
          if (hn === nn || hc === nc) return i;
        }
      }
      return -1;
    }

    var orderIdIndex = findIndex(["Order ID", "OrderID", "ID", "Order Id"]);
    var dateIndex = findIndex(["Date", "Order Date"]);
    var usernameIndex = findIndex(["Username", "User", "User Name"]);
    var totalAmountIndex = findIndex(["Total Amount", "Total", "Amount", "Grand Total"]);
    var paymentMethodIndex = findIndex(["Payment Method", "Payment", "Method"]);
    var cashHandlerIndex = findIndex(["Cash Handler", "Cashier", "Handled By"]);
    var itemsIndex = findIndex(["Items", "Order Items", "Products"]);
    var statusIndex = findIndex(["Status", "Order Status"]);

    // If critical indices are missing, return empty to avoid breaking client
    if (orderIdIndex < 0 || dateIndex < 0 || usernameIndex < 0 || itemsIndex < 0) {
      return ContentService.createTextOutput(JSON.stringify([]))
        .setMimeType(ContentService.MimeType.JSON);
    }

    var uname = String(username || '').trim().toLowerCase();
    // Admin view if username is 'admin', 'all', or empty
    var isAdminView = (uname === 'admin' || uname === 'all' || uname === '');
    for (var i = 1; i < data.length; i++) {
      var rowUsername = String(data[i][usernameIndex] || '').trim().toLowerCase();
      if (isAdminView || rowUsername === uname) {
        var items;
        try {
          items = JSON.parse(data[i][itemsIndex]);
        } catch (e) {
          items = data[i][itemsIndex];
        }
        orders.push({
          id: data[i][orderIdIndex],
          date: formatDate(data[i][dateIndex]),
          username: data[i][usernameIndex],
          items: items,
          totalAmount: totalAmountIndex >= 0 ? data[i][totalAmountIndex] : '',
          paymentMethod: paymentMethodIndex >= 0 ? data[i][paymentMethodIndex] : '',
          cashHandler: cashHandlerIndex >= 0 ? data[i][cashHandlerIndex] : '',
          status: statusIndex >= 0 ? data[i][statusIndex] : ''
        });
      }
    }

    orders.sort((a, b) => new Date(b.date) - new Date(a.date));

    return ContentService.createTextOutput(JSON.stringify(orders))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return createJsonResponse({
      success: false,
      message: "Error getting orders data: " + error.toString()
    });
  }
}

function formatDate(date) {
  if (!(date instanceof Date)) date = new Date(date);
  return date.toLocaleDateString('en-IN', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
}


// Shared configuration
const CONFIG = {
  SHEET_ID: "1a880pba8mZJS-QQVzwGUEdvXxeXCRhQa1n56htBRD8w"
};

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    if (data.action === 'increaseStock') {
      return increaseStock(data);
    }
    return ContentService.createTextOutput(JSON.stringify({success: false, message: 'Invalid action'}))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({success: false, message: err.toString()}))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function increaseStock(data) {
  var sheet = SpreadsheetApp.openById(CONFIG.SHEET_ID).getSheetByName('Inventory');
  var productId = data.productId;
  var qtyToAdd = Number(data.quantity);

  if (!productId || isNaN(qtyToAdd) || qtyToAdd <= 0) {
    return ContentService.createTextOutput(JSON.stringify({success: false, message: 'Invalid input'}))
      .setMimeType(ContentService.MimeType.JSON);
  }

  var range = sheet.getDataRange();
  var values = range.getValues();
  var idCol = values[0].indexOf('S.No'); // or 'ID' if that's your column name
  var qtyCol = values[0].indexOf('Qty');
  var balCol = values[0].indexOf('Bal');

  for (var i = 1; i < values.length; i++) {
    if (values[i][idCol].toString() === productId.toString()) {
      var currentQty = Number(values[i][qtyCol]) || 0;
      var currentBal = Number(values[i][balCol]) || 0;
      sheet.getRange(i+1, qtyCol+1).setValue(currentQty + qtyToAdd);
      sheet.getRange(i+1, balCol+1).setValue(currentBal + qtyToAdd);
      return ContentService.createTextOutput(JSON.stringify({success: true}))
        .setMimeType(ContentService.MimeType.JSON);
    }
  }
  return ContentService.createTextOutput(JSON.stringify({success: false, message: 'Product not found'}))
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    if (data.action === 'decreaseStock') {
      return decreaseStock(data);
    }
    return ContentService.createTextOutput(JSON.stringify({success: false, message: 'Invalid action'}))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({success: false, message: err.toString()}))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function decreaseStock(data) {
  var sheet = SpreadsheetApp.openById(CONFIG.SHEET_ID).getSheetByName('Inventory');
  var productId = data.productId;
  var qtyToRemove = Number(data.quantity);

  if (!productId || isNaN(qtyToRemove) || qtyToRemove <= 0) {
    return ContentService.createTextOutput(JSON.stringify({success: false, message: 'Invalid input'}))
      .setMimeType(ContentService.MimeType.JSON);
  }

  var range = sheet.getDataRange();
  var values = range.getValues();
  var idCol = values[0].indexOf('S.No'); // or 'ID' if that's your column name
  var qtyCol = values[0].indexOf('Qty');
  var balCol = values[0].indexOf('Bal');

  for (var i = 1; i < values.length; i++) {
    if (values[i][idCol].toString() === productId.toString()) {
      var currentQty = Number(values[i][qtyCol]) || 0;
      var currentBal = Number(values[i][balCol]) || 0;
      
      // Check if we have enough stock to decrease
      if (currentBal < qtyToRemove) {
        return ContentService.createTextOutput(JSON.stringify({
          success: false, 
          message: 'Not enough stock available. Current balance: ' + currentBal
        }))
        .setMimeType(ContentService.MimeType.JSON);
      }

      // Update both Qty and Bal columns
      sheet.getRange(i+1, qtyCol+1).setValue(currentQty - qtyToRemove);
      sheet.getRange(i+1, balCol+1).setValue(currentBal - qtyToRemove);
      
      return ContentService.createTextOutput(JSON.stringify({success: true}))
        .setMimeType(ContentService.MimeType.JSON);
    }
  }
  
  return ContentService.createTextOutput(JSON.stringify({success: false, message: 'Product not found'}))
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    var data = e && e.postData && e.postData.contents ? JSON.parse(e.postData.contents) : {};
    var action = data.action;
    switch (action) {
      case 'login':
        var ss = SpreadsheetApp.openById(CONFIG.SHEET_ID);
        initializeSheets(ss);
        return handleLogin(ss, data);
      case 'submitOrder': {
        var ss1 = SpreadsheetApp.openById(CONFIG.SHEET_ID);
        initializeSheets(ss1);
        return handleOrderSubmission(ss1, data);
      }
      case 'deleteOrder': {
        var ss2 = SpreadsheetApp.openById(CONFIG.SHEET_ID);
        initializeSheets(ss2);
        return handleOrderDeletion(ss2, data);
      }
      case 'increaseStock':
        return handleStockUpdate(data, true);
      case 'decreaseStock':
        return handleStockUpdate(data, false);
      default:
        return ContentService.createTextOutput(JSON.stringify({ success: false, message: 'Invalid action' }))
          .setMimeType(ContentService.MimeType.JSON);
    }
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ success: false, message: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function handleStockUpdate(data, isIncrease) {
  var sheet = SpreadsheetApp.openById(CONFIG.SHEET_ID).getSheetByName('Inventory');
  var productId = data.productId;
  var quantity = Number(data.quantity);

  // Validate input
  if (!productId || isNaN(quantity) || quantity <= 0) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false, 
      message: 'Invalid input'
    })).setMimeType(ContentService.MimeType.JSON);
  }

  var range = sheet.getDataRange();
  var values = range.getValues();
  var idCol = values[0].indexOf('S.No');
  var qtyCol = values[0].indexOf('Qty');
  var balCol = values[0].indexOf('Bal');

  // Find the product
  for (var i = 1; i < values.length; i++) {
    if (values[i][idCol].toString() === productId.toString()) {
      var currentQty = Number(values[i][qtyCol]) || 0;
      var currentBal = Number(values[i][balCol]) || 0;
      
      // For decrease operation, check if we have enough stock
      if (!isIncrease && currentBal < quantity) {
        return ContentService.createTextOutput(JSON.stringify({
          success: false, 
          message: 'Not enough stock available. Current balance: ' + currentBal
        })).setMimeType(ContentService.MimeType.JSON);
      }

      // Calculate new values
      var newQty = isIncrease ? currentQty + quantity : currentQty - quantity;
      var newBal = isIncrease ? currentBal + quantity : currentBal - quantity;

      // Update the sheet
      sheet.getRange(i+1, qtyCol+1).setValue(newQty);
      sheet.getRange(i+1, balCol+1).setValue(newBal);

      // Log the operation
      logStockOperation(productId, values[i][values[0].indexOf('Particulars')], 
                       isIncrease ? 'Increase' : 'Decrease', 
                       quantity, currentBal, newBal);

      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        newStock: newBal
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }
  
  return ContentService.createTextOutput(JSON.stringify({
    success: false, 
    message: 'Product not found'
  })).setMimeType(ContentService.MimeType.JSON);
}

function logStockOperation(productId, productName, operation, quantity, previousStock, newStock) {
  var logSheet = SpreadsheetApp.openById(CONFIG.SHEET_ID).getSheetByName('StockLog');
  if (!logSheet) {
    logSheet = SpreadsheetApp.openById(CONFIG.SHEET_ID).insertSheet('StockLog');
    logSheet.appendRow(['Timestamp', 'Product ID', 'Product Name', 'Operation', 'Quantity Changed', 'Previous Stock', 'New Stock']);
  }
  
  logSheet.appendRow([
    new Date(),
    productId,
    productName,
    operation,
    quantity,
    previousStock,
    newStock
  ]);
}

function doGet(e) {
  try {
    var p = e && e.parameter ? e.parameter : {};
    var action = p.action;
    if (action === 'getInventory') {
      return getInventoryData();
    } else if (action === 'getOrders') {
      return getOrdersData(p.username);
    } else if (action === 'qtySummary') {
      return getQtySummary();
    }
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      message: 'Invalid action'
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}