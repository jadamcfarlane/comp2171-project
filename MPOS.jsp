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
    <title>Manager POS Dashboard</title>
    <link href="MPOS.css" rel="stylesheet"/>
</head>
<body>

<div class="layout">
    <div class="sidebar">
        <img src="logo.jpg" style="height:173px;width:221px">
        <div class="logo">MSOL JAMAICA LTD</div>

        <a href="logout.jsp?from=Manager Dashboard" class="sidebar-btn logout-btn">Logout</a>

        <form action="SalesController.jsp" method="post">
            <input type="hidden" name="action" value="new">
            <input type="hidden" name="source" value="MPOS">
            <button class="sidebar-btn">+ New Order</button>
        </form>

        <div class="user-box">
            <strong>Manager</strong>
        </div>
    </div>

    <div class="main">
        <div class="cards">
            <div class="card babyblue">
                <div class="icon"><img src="sales.png"></div>
                <div class="content">Sales Overview</div>
                <a href="Sales.jsp" class="btnsubmit"> CLICK HERE</a>
            </div>
            <div class="card babyblue">
                <div class="icon"><img src="custhistory.png"></div>
                <div class="content">Customer History</div>
                <a href="custhistory.jsp?from=MPOS" class="btnsubmit"> CLICK HERE</a>
            </div>
            <div class="card mayablue">
                <div class="icon"><img src="inventory.png"></div>
                <div class="content">Inventory Overview</div>
                <a href="inventory.jsp" class="btnsubmit"> CLICK HERE</a>
            </div>
            <div class="card argentianblue">
                <div class="icon"><img src="reports.png"></div>
                <div class="content">Reports</div>
                <a href="Report.jsp" class="btnsubmit"> GENERATE REPORT</a>
            </div>
            <div class="card tuftsblue">
                <div class="icon"><img src="credentials.png"></div>
                <div class="content">User Credentials</div>
                <a href="usercred.jsp" class="btnsubmit"> CLICK HERE</a>
            </div>
        </div>

        <div class="order-section">
            <div class="order-box">
                <h2>New Order</h2>
                <form action="SalesController.jsp" method="post">
                    <input type="hidden" name="action" value="search">
                    <input type="hidden" name="source" value="MPOS">
                    <input type="text" name="search" class="search-input" placeholder="Search items...">
                    <button class="search-btn">Search</button>
                </form>

                <table class="grid-items">
                    <tr><th>Item</th><th>Price</th><th>Action</th></tr>
                    <% if(items != null) { for(Map<String,Object> item : items) { %>
                    <tr>
                        <td><%=item.get("name")%></td>
                        <td>$<%=item.get("price")%></td>
                        <td>
                            <form action="SalesController.jsp" method="post">
                                <input type="hidden" name="action" value="add">
                                <input type="hidden" name="source" value="MPOS">
                                <input type="hidden" name="id" value="<%=item.get("id")%>">
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
                        <td><%=item.get("name")%></td>
                        <td>
                            <form action="SalesController.jsp" method="post" style="display:inline;">
                                <input type="hidden" name="action" value="update">
                                <input type="hidden" name="source" value="MPOS">
                                <input type="hidden" name="id" value="<%=item.get("id")%>">
                                <input type="number" name="qty" value="<%=qty%>" min="1" style="width:50px;">
                                <button type="submit" style="padding:2px 5px;">Set</button>
                            </form>
                        </td>
                        <td>$<%=String.format("%.2f", price)%></td>
                        <td>$<%=String.format("%.2f", total)%></td>
                        <td>
                            <form action="SalesController.jsp" method="post">
                                <input type="hidden" name="action" value="remove">
                                <input type="hidden" name="source" value="MPOS">
                                <input type="hidden" name="id" value="<%=item.get("id")%>">
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
                <div class="total-line">Subtotal: $<%=String.format("%.2f", subtotal)%></div>
                <div class="total-line">Tax (5%): $<%=String.format("%.2f", tax)%></div>
                <div class="grand-total">Total: $<%=String.format("%.2f", grandTotal)%></div>

                <form action="SalesController.jsp" method="post">
                    <input type="hidden" name="action" value="checkout">
                    <input type="hidden" name="source" value="MPOS">
                    
                    <div class="customer-box">
                        <label>Assign Customer</label>
                        <select name="selectedCustomerId">
                            <option value="0">-- Walk-in Customer --</option>
                            <% for(String[] c : activeCustomers) { %>
                                <option value="<%= c[0] %>"><%= c[1] %></option>
                            <% } %>
                        </select>
                        <div style="text-align:right; margin-top:4px;">
                            <a href="custcreate.jsp?from=MPOS" target="_blank">+ New Customer</a>
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

                <% if(sessionObj.getAttribute("showReceipt") != null){ %>
                   <a href="SalesController.jsp?action=pdf&source=MPOS" class="print-btn" style="text-decoration:none; display:inline-block; text-align:center; margin-top:5px; background:#2ecc71;">Download PDF</a>
                <% } %>

                <% if(sessionObj.getAttribute("showReceipt") != null && (Boolean)sessionObj.getAttribute("showReceipt")){ %>
                    <div class="receipt-card" id="receiptArea">
                        <h3> Receipt Preview </h3>
                        <%= sessionObj.getAttribute("receiptHTML") %>
                    </div>
                <% } %>
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