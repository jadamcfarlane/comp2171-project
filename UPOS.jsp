<%@ page import="java.sql.*,java.io.*" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.HashMap" %>
<%@ include file="config.jsp" %>

<%
    java.util.List<Map<String,Object>> cart = (java.util.List<Map<String,Object>>) sessionObj.getAttribute("cart");
    if (cart == null) {
        cart = new ArrayList<>();
        sessionObj.setAttribute("cart", cart);
    }

    java.util.List<Map<String,Object>> items = (java.util.List<Map<String,Object>>) request.getAttribute("searchResults");

    java.util.List<String[]> activeCustomers = new ArrayList<>();
    try {
        Statement stmt = conn.createStatement();
        ResultSet rsCust = stmt.executeQuery("SELECT CustomerID, CustomerName FROM Customers ORDER BY CustomerName");
        while(rsCust.next()) {
            activeCustomers.add(new String[]{rsCust.getString("CustomerID"), rsCust.getString("CustomerName")});
        }
        rsCust.close();
        stmt.close();
    } catch (Exception e) { e.printStackTrace(); }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Cashier POS Dashboard</title>
    <link rel="stylesheet" href="UPOS.css">
</head>

<header>
    <ul class="navigation">
        <li><a href="custhistory.jsp?from=UPOS">Customer History</a></li>
        <li><a href="logout.jsp?from=User POS" >Logout</a></li>
    </ul>
</header>

<body>

<div class="layout">
    <div class="sidebar">
        <img src="logo.jpg" style="height:170px;width:220px;">
        <div class="logo">MSOL JAMAICA LTD</div>

        <form action="SalesController.jsp" method="post">
            <input type="hidden" name="action" value="new">
            <input type="hidden" name="source" value="UPOS">
            <button class="sidebar-btn">+ New Order</button>
        </form>

        <div class="user-box">
            <strong>Cashier: <%= sessionObj.getAttribute("username") %></strong>
        </div>
    </div>

    <div class="order-section">
        <div class="order-box">
            <h2>New Order</h2>
            <form method="post" action="SalesController.jsp">
                <input type="hidden" name="action" value="search">
                <input type="hidden" name="source" value="UPOS">
                <input type="text" name="search" class="search-input" placeholder="Search items...">
                <button class="search-btn">Search</button>
            </form>

            <table class="grid-items">
                <tr><th>Item</th><th>Price</th><th>Action</th></tr>
                <% if(items != null) { for(Map<String,Object> item : items) { %>
                <tr>
                    <td><%= item.get("name") %></td>
                    <td>$<%= String.format("%.2f", (double)item.get("price")) %></td>
                    <td>
                        <form action="SalesController.jsp" method="post">
                            <input type="hidden" name="action" value="add">
                            <input type="hidden" name="source" value="UPOS">
                            <input type="hidden" name="id" value="<%= item.get("id") %>">
                            <button>Add</button>
                        </form>
                    </td>
                </tr>
                <% }} %>
            </table>

            <h2>Items to Checkout</h2>
            <table class="gv-container">
                <tr><th>Item</th><th>Qty</th><th>Price</th><th>Total</th><th>Action</th></tr>
                <% 
                    double subtotal = 0;
                    for(Map<String,Object> item : cart) {
                        int qty = (int)item.get("qty");
                        double price = ((Number)item.get("price")).doubleValue();
                        double total = qty * price;
                        subtotal += total;
                %>
                <tr>
                    <td><%= item.get("name") %></td>
                    <td>
                        <form action="SalesController.jsp" method="post" style="display:inline;">
                            <input type="hidden" name="action" value="update">
                            <input type="hidden" name="source" value="UPOS">
                            <input type="hidden" name="id" value="<%= item.get("id") %>">
                            <input type="number" name="qty" value="<%= qty %>" min="1" style="width:50px;">
                            <button type="submit">Set</button>
                        </form>
                    </td>
                    <td>$<%= String.format("%.2f", price) %></td>
                    <td>$<%= String.format("%.2f", total) %></td>
                    <td>
                        <form action="SalesController.jsp" method="post">
                            <input type="hidden" name="action" value="remove">
                            <input type="hidden" name="source" value="UPOS">
                            <input type="hidden" name="id" value="<%= item.get("id") %>">
                            <button>Remove</button>
                        </form>
                    </td>
                </tr>
                <% } %>
            </table>
        </div>

        <div class="totals-box">
            <h3>Summary</h3>
            <% 
                double tax = subtotal * 0.05;
                double grandTotal = subtotal + tax;
            %>
            <div class="total-line">Subtotal: $<%= String.format("%.2f", subtotal) %></div>
            <div class="total-line">Tax (5%): $<%= String.format("%.2f", tax) %></div>
            <div class="grand-total">Total: $<%= String.format("%.2f", grandTotal) %></div>

            <form action="SalesController.jsp" method="post">
                <input type="hidden" name="action" value="checkout">
                <input type="hidden" name="source" value="UPOS">
                
                <div class="customer-box">
                    <label>Assign Customer</label>
                    <select name="selectedCustomerId">
                        <option value="0">-- Walk-in Customer --</option>
                        <% for(String[] c : activeCustomers) { %>
                            <option value="<%= c[0] %>"><%= c[1] %></option>
                        <% } %>
                    </select>
                    <div style="text-align:right; margin-top:4px;">
                        <a href="custcreate.jsp?from=UPOS" target="_blank">+ New Customer</a>
                    </div>
                </div>

                <label>Payment Method</label>
                <select name="paymentMethod" class="payment-select">
                    <option value="Cash">Cash</option>
                    <option value="Card">Card</option>
                </select>
                
                <button type="submit" class="checkout-btn">Check Out</button>
            </form>

            <button class="print-btn" onclick="printReceipt()">Print Receipt</button>

            <% if(sessionObj.getAttribute("showReceipt") != null && (Boolean)sessionObj.getAttribute("showReceipt")){ %>
                <div class="receipt-card" id="receiptArea">
                    <h3> Receipt Preview </h3>
                    <%= sessionObj.getAttribute("receiptHTML") %>
                </div>
            <% } %>
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