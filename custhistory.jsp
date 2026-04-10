<%@ page import="java.sql.*, java.util.*" %>

<%
    HttpSession sessionObj = request.getSession(false);
    if (sessionObj == null || sessionObj.getAttribute("username") == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String fromPage = request.getParameter("from");
    if (fromPage == null || fromPage.isEmpty()) { 
        fromPage = "UPOS"; 
    }

    String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";
    String customerId = request.getParameter("customerId");
    List<Map<String,Object>> purchaseHistory = new ArrayList<>();

    try {
        Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        Connection con = DriverManager.getConnection(connStr);

        String sql = "SELECT s.ReceiptNo, " +
                     "MAX(s.DateSold) AS DateSold, " +
                     "SUM(s.Total) AS GrandTotal, " +
                     "MAX(c.CustomerName) AS CustomerName, " +
                     "STUFF((SELECT ', ' + i.ItemName + ' (x' + CAST(s2.Qty AS VARCHAR) + ')' " +
                     "       FROM Sales s2 " +
                     "       JOIN Item i ON s2.ItemID = i.ItemID " +
                     "       WHERE s2.ReceiptNo = s.ReceiptNo " +
                     "       FOR XML PATH('')), 1, 2, '') AS ItemsList " +
                     "FROM Sales s " +
                     "LEFT JOIN Customers c ON s.CustomerID = c.CustomerID " +
                     "GROUP BY s.ReceiptNo " +
                     "ORDER BY DateSold DESC";

        PreparedStatement ps = con.prepareStatement(sql);
        ResultSet rs = ps.executeQuery();

        
        while (rs.next()) {
            Map<String, Object> row = new HashMap<>();
            row.put("date", rs.getTimestamp("DateSold"));
            row.put("customer", rs.getString("CustomerName") != null ? rs.getString("CustomerName") : "Walk-in");
            row.put("receipt", rs.getString("ReceiptNo"));
            row.put("total", rs.getDouble("GrandTotal"));
            row.put("items", rs.getString("ItemsList") != null ? rs.getString("ItemsList") : "No items listed");
            purchaseHistory.add(row);
        }

        rs.close();
        ps.close();
        if (con != null) { con.close(); }

    } catch(Exception e) { e.printStackTrace(); }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Customer History</title>
    <link rel="stylesheet" href="UserActivity.css"> </head>
<body>
    <header>
        <ul class="navigation">
            <li><a href="<%= fromPage %>.jsp">Dashboard</a></li>

            <% 
                // Only show Sales link if the user is NOT on UPOS
                if (!"UPOS".equalsIgnoreCase(fromPage)) { 
            %>
                <li><a href="Sales.jsp">Sales</a></li>
            <% 
                } 
            %>
            <li><a href="logout.jsp?from=Customer History">Sign Out</a></li>
        </ul>
    </header>

    <div class="main">
        <h1>Customer Purchase History</h1>
        
        <table class="grid-items"> <thead>
                <tr>
                    <th>Date & Time Sold</th>
                    <th>Customer Name</th>
                    <th>Items Purchased</th>
                    <th>Receipt #</th>
                    <th>Total Amount</th>
                </tr>
            </thead>
            <tbody>
                <% for(Map<String,Object> sale : purchaseHistory) { %>
                <tr>
                    <td><%= sale.get("date") %></td>
                    <td><strong><%= sale.get("customer") %></strong></td>
                    <td style="font-size: 0.9em; color: #555;">
                        <%= sale.get("items") %>
                    </td>
                    <td><%= sale.get("receipt") %></td>
                    <td>$<%= String.format("%.2f", (Double)sale.get("total")) %></td>
                </tr>
                <% } %>
            </tbody>
        </table>
    </div>
</body>
</html>