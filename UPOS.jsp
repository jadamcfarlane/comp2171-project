<%@ page import="java.util.*" %>
<%@ page import="java.sql.*,java.io.*" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.HashMap" %>
<%@ page import="com.itextpdf.text.*" %>
<%@ page import="com.itextpdf.text.pdf.*" %>

<%
HttpSession sessionObj = request.getSession(false);

if (sessionObj == null || sessionObj.getAttribute("username") == null) {
    response.sendRedirect("login.jsp");
    return;
}

java.util.List<Map<String,Object>> cart =
(java.util.List<Map<String,Object>>) sessionObj.getAttribute("cart");

if (cart == null) {
    cart = new ArrayList<>();
    sessionObj.setAttribute("cart", cart);
}

String action = request.getParameter("action");

String connStr =
"jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";

java.util.List<Map<String,Object>> items = null;

try {

Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
Connection con = DriverManager.getConnection(connStr);

if ("search".equals(action)) {

    String search = request.getParameter("search");

    PreparedStatement ps = con.prepareStatement(
    "SELECT ItemID, ItemName, Price FROM Item WHERE ItemName LIKE ?");

    ps.setString(1,"%"+search+"%");

    ResultSet rs = ps.executeQuery();

    items = new ArrayList<>();

    while(rs.next()){

        Map<String,Object> item = new HashMap<>();

        item.put("id",rs.getInt("ItemID"));
        item.put("name",rs.getString("ItemName"));
        item.put("price",rs.getDouble("Price"));

        items.add(item);
    }

    rs.close();
    ps.close();
}


if ("add".equals(action)) {

    int id = Integer.parseInt(request.getParameter("id"));

    PreparedStatement ps = con.prepareStatement(
    "SELECT ItemName, Price, Stock FROM Item WHERE ItemID=?");

    ps.setInt(1,id);

    ResultSet rs = ps.executeQuery();

    if(rs.next()){

        int stock = rs.getInt("Stock");
        int currentyQty=0;

        boolean found = false;

        for(Map<String,Object> item : cart){

            if((int)item.get("id")==id){

                currentyQty=(int)item.get("qty");
                found=true;
            }
        }

        if(currentyQty+1 > stock){
            out.println("<script>alert('Not enough stock available');</script>");
        }else{

            if(found){

                for(Map<String,Object> item: cart){

                    if((int)item.get("id")==id){
                        item.put("qty",(int)item.get("qty")+1);
                    }
                }
            }else{

                Map<String,Object> newItem = new HashMap<>();

                newItem.put("id",id);
                newItem.put("name",rs.getString("ItemName"));
                newItem.put("price",rs.getDouble("Price"));
                newItem.put("qty",1);

                cart.add(newItem);
            }
        }
    }

    rs.close();
    ps.close();
}

if("update".equals(action)){

    int id=Integer.parseInt(request.getParameter("id"));
    int qty=Integer.parseInt(request.getParameter("qty"));

    for(Map<String,Object> item : cart){

        if((int)item.get("id")==id){

            item.put("qty",Math.max(qty,1));
        }
    }
}

if("remove".equals(action)){

    int id=Integer.parseInt(request.getParameter("id"));

    cart.removeIf(i -> (int)i.get("id")==id);
}

if("new".equals(action)){
    cart.clear();
    sessionObj.removeAttribute("showReceipt");
    sessionObj.removeAttribute("receiptHTML");
    sessionObj.removeAttribute("lastCart");
}

if ("checkout".equals(action)) {
    if (cart == null || cart.isEmpty()) {
        out.println("<script>alert('Cart is empty');</script>");
    } else {
        try {
            
            String paymentMethod = request.getParameter("paymentMethod");
            if (paymentMethod == null) paymentMethod = "Cash";
            
            String cashier = (sessionObj.getAttribute("username") != null) 
                             ? sessionObj.getAttribute("username").toString() : "Unknown";
            
            String receiptNo = "R" + new java.text.SimpleDateFormat("yyyyMMddHHmmss").format(new java.util.Date());
            StringBuilder sb = new StringBuilder();
            double subtotal = 0;

            sb.append("<div style='text-align:center;'>");
            sb.append("<img src='" + request.getContextPath() + "/logo.jpg' style='width:120px'><br>");
            sb.append("<h2>MSOL JAMAICA LTD</h2>");
            sb.append("<h4>Red Bank, Red Bank District | 876-291-4000</h4>");
            sb.append("<h4>Receipt No: " + receiptNo + "</h4>");
            sb.append("<p>Date: " + new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new java.util.Date()) + "</p>");
            sb.append("<p><strong>Cashier:</strong> " + cashier + " | <strong>Payment:</strong> " + paymentMethod + "</p>");
            sb.append("</div><hr/>");

            
            sb.append("<table style='width:100%; border-collapse:collapse;'>");
            sb.append("<tr><th align='left'>Item</th><th>Qty</th><th>Price</th><th>Total</th></tr>");

            for (Map<String, Object> item : cart) {
                String name = item.get("name").toString();
                int itemId = (int) item.get("id");
                int qty = (int) item.get("qty");
                double price = ((Number) item.get("price")).doubleValue();
                double total = qty * price;
                subtotal += total;

                sb.append("<tr>");
                sb.append("<td>" + name + "</td>");
                sb.append("<td align='center'>" + qty + "</td>");
                sb.append("<td align='center'>$" + String.format("%.2f", price) + "</td>");
                sb.append("<td align='center'>$" + String.format("%.2f", total) + "</td>");
                sb.append("</tr>");

                // DB: Sales
                PreparedStatement psSales = con.prepareStatement(
                    "INSERT INTO Sales (ReceiptNo, ItemID, Qty, Price, Total, DateSold, ReceiptHTML) VALUES (?, ?, ?, ?, ?, GETDATE(), '')"
                );
                psSales.setString(1, receiptNo);
                psSales.setInt(2, itemId);
                psSales.setInt(3, qty);
                psSales.setDouble(4, price);
                psSales.setDouble(5, total);
                psSales.executeUpdate();
                psSales.close();

                // DB: Update Stock 
                PreparedStatement psUpdate = con.prepareStatement(
                    "UPDATE Item SET Stock = Stock - ?, LastSoldQty = ? WHERE ItemID = ? AND Stock >= ?"
                );
                psUpdate.setInt(1, qty);
                psUpdate.setInt(2, qty);
                psUpdate.setInt(3, itemId);
                psUpdate.setInt(4, qty);
                psUpdate.executeUpdate();
                psUpdate.close();
            }

            double tax = subtotal * 0.05;
            double grandTotal = subtotal + tax;

            sb.append("</table><hr/>");
            sb.append("<p align='right'>Subtotal: $" + String.format("%.2f", subtotal) + "</p>");
            sb.append("<p align='right'>Tax (5%): $" + String.format("%.2f", tax) + "</p>");
            sb.append("<h3 align='right'>Total: $" + String.format("%.2f", grandTotal) + "</h3>");
            sb.append("<p style='text-align:center;'>Thank you for your purchase!</p>");

            // HTML record in DB
            PreparedStatement psFinal = con.prepareStatement("UPDATE Sales SET ReceiptHTML=? WHERE ReceiptNo=?");
            psFinal.setString(1, sb.toString());
            psFinal.setString(2, receiptNo);
            psFinal.executeUpdate();
            psFinal.close();

            // UI to display
            sessionObj.setAttribute("lastCart", new ArrayList<>(cart));
            sessionObj.setAttribute("receiptHTML", sb.toString());
            sessionObj.setAttribute("paymentMethod", paymentMethod);
            sessionObj.setAttribute("cashier", cashier);
            sessionObj.setAttribute("showReceipt", true);
            sessionObj.setAttribute("subtotal", subtotal);
            sessionObj.setAttribute("tax", tax);
            sessionObj.setAttribute("grandTotal", grandTotal);

            cart.clear(); 
            sessionObj.setAttribute("cart", cart);

        } catch (Exception e) {
            out.println("<div style='color:red;'>Error during checkout: " + e.getMessage() + "</div>");
            e.printStackTrace();
        }
    }
}

if("receipt".equals(action)){

    java.util.List<Map<String,Object>> lastCart=
    (java.util.List<Map<String,Object>>)sessionObj.getAttribute("lastCart");

    double subtotal=(double)sessionObj.getAttribute("subtotal");
    double tax=(double)sessionObj.getAttribute("tax");
    double grandTotal=(double)sessionObj.getAttribute("grandTotal");

    response.setContentType("application/pdf");
    response.setHeader("Content-Disposition","attachment; filename=receipt.pdf");

    Document document=new Document();
    PdfWriter.getInstance(document,response.getOutputStream());

    document.open();

    document.add(new Paragraph("MSOL JAMAICA LTD"));
    document.add(new Paragraph("Sales Receipt\n"));

    String paymentMethod = sessionObj.getAttribute("paymentMethod").toString();
    String cashier = sessionObj.getAttribute("cashier").toString();

    document.add(new Paragraph("Cashier: " + cashier));
    document.add(new Paragraph("Payment Method: " + paymentMethod));
    document.add(new Paragraph(" "));

    PdfPTable table=new PdfPTable(4);

    table.addCell("Item");
    table.addCell("Qty");
    table.addCell("Price");
    table.addCell("Total");

    for(Map<String,Object> item : lastCart){

        int qty=(int)item.get("qty");
        double price=(double)item.get("price");

        table.addCell(item.get("name").toString());
        table.addCell(String.valueOf(qty));
        table.addCell("$" + String.format("%.2f", price));
        table.addCell("$" + String.format("%.2f", (qty * price)));
    }

    document.add(table);

    document.add(new Paragraph("\nSubtotal: $" + String.format("%.2f", subtotal)));
    document.add(new Paragraph("Tax (5%): $" + String.format("%.2f", tax)));
    document.add(new Paragraph("Grand Total: $" + String.format("%.2f", grandTotal)));

    document.close();
    return;
}

con.close();

}catch(Exception e){
e.printStackTrace();
}

sessionObj.setAttribute("cart",cart);
%>

<!DOCTYPE html>
<html>
<head>
<title>Cashier POS Dashboard</title>
<link rel="stylesheet" href="UPOS.css">
</head>

<body>

<div class="layout">

<div class="sidebar">

<img src="logo.jpg" style="height:170px;width:220px;">
<div class="logo">MSOL JAMAICA LTD</div>

<a href="logout.jsp" class="sidebar-btn logout-btn">Logout</a>

<form action="UPOS.jsp" method="post">
<input type="hidden" name="action" value="new">
<button class="sidebar-btn">+ New Order</button>
</form>

<div class="user-box">
<strong>Cashier: <%= sessionObj.getAttribute("username") %></strong>
</div>

</div>

<div class="order-section">

<div class="order-box">

<h2>New Order</h2>

<form method="post" action="UPOS.jsp">
<input type="hidden" name="action" value="search">
<input type="text" name="search" class="search-input" placeholder="Search items...">
<button class="search-btn">Search</button>
</form>


<table class="grid-items">

<tr>
<th>Item</th>
<th>Price</th>
<th>Action</th>
</tr>

<%

if(items != null){

for(Map<String,Object> item : items){
%>

<tr>

<td><%= item.get("name") %></td>
<td>$<%= item.get("price") %></td>

<td>

<form action="UPOS.jsp" method="post">

<input type="hidden" name="action" value="add">
<input type="hidden" name="id" value="<%= item.get("id") %>">

<button>Add</button>

</form>

</td>

</tr>

<%
}
}
%>

</table>


<h2>Items to Checkout</h2>

<table class="gv-container">

<tr>
<th>Item</th>
<th>Qty</th>
<th>Price</th>
<th>Total</th>
<th>Action</th>
</tr>

<%

cart = (java.util.List<Map<String,Object>>) sessionObj.getAttribute("cart");

double subtotal = 0;

if(cart != null){

for(Map<String,Object> item : cart){

int qty = (int)item.get("qty");
double price = (double)item.get("price");
double total = qty * price;

subtotal += total;
%>

<tr>

<td><%= item.get("name") %></td>

<td>

<form action="UPOS.jsp" method="post">

<input type="hidden" name="action" value="update">
<input type="hidden" name="id" value="<%= item.get("id") %>">

<input type="number" name="qty" value="<%= qty %>" min="1">

<button>Update</button>

</form>

</td>

<td>$<%= price %></td>
<td>$<%= total %></td>

<td>

<form action="UPOS.jsp" method="post">

<input type="hidden" name="action" value="remove">
<input type="hidden" name="id" value="<%= item.get("id") %>">

<button>Remove</button>

</form>

</td>

</tr>

<%
}
}
%>

</table>

</div>

<div class="totals-box">

<h3>Summary</h3>

<%
double tax = subtotal * 0.05;
double grandTotal = subtotal + tax;
%>

<div class="total-line">
Subtotal: $<%= subtotal %>
</div>

<div class="total-line">
Tax (5%): $<%= tax %>
</div>

<div class="grand-total">
Total: $<%= grandTotal %>
</div>


<label>Payment Method</label>

<select name="paymentMethod" form="checkoutForm" class="payment-select">
<option value="Cash">Cash</option>
<option value="Card">Card</option>
<!-- <option value="Mobile">Mobile</option> -->
</select>

<form id="checkoutForm" action="UPOS.jsp" method="post">
<input type="hidden" name="action" value="checkout">
<button class="checkout-btn">Check Out</button>

</form>


<button class="print-btn" onclick="printReceipt()">Print Receipt</button>

<%
Boolean showReceipt = (Boolean)sessionObj.getAttribute("showReceipt");

if(showReceipt != null && showReceipt){
%>

<div class="receipt-card" id="receiptArea">

<h3> Receipt Preview </h3>

<%= sessionObj.getAttribute("receiptHTML") %>

</div>

<button class="print-btn" onclick="printReceipt()">Print Receipt</button>

<%
}
%>  

</div>

</div>

</div>

</div>

</div>

<script>
function printReceipt() {

    var receipt = document.getElementById("receiptArea");

    if(!receipt){
        alert("No receipt available.");
        return;
    }
    
    var printWindow = window.open('', '', 'width=600,height=700');
    printWindow.document.write('<html><head><title>Receipt</title></head><body>');
    printWindow.document.write(receipt.innerHTML);
    printWindow.document.write('</body></html>');
    printWindow.document.close();
    printWindow.print();

}
</script>

</body>
</html>