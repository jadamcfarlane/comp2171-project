<%@ page import="java.sql.*, java.util.*" %>
<%
    HttpSession sessionObj = request.getSession(false);
    if (sessionObj == null || sessionObj.getAttribute("username") == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String fromPage = request.getParameter("from");
    if (fromPage == null || fromPage.isEmpty()) { fromPage = "UPOS"; }

    String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";
    String message = "";
    
    String name = request.getParameter("custName");
    String phone = request.getParameter("custPhone");
    String email = request.getParameter("email");
    String action = request.getParameter("action");

    try {
        Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        Connection conn = DriverManager.getConnection(connStr);

        if ("save".equals(action) && name != null && !name.isEmpty()) {
            PreparedStatement ps = conn.prepareStatement("INSERT INTO Customers (CustomerName, ContactNumber, Email) VALUES (?, ?, ?)");
            ps.setString(1, name);
            ps.setString(2, phone);
            ps.setString(3, email);
            ps.executeUpdate();
            ps.close();
            message = "Customer Added Successfully! Redirecting to POS...";

            out.println("<script>");
            out.println("setTimeout(function() { window.location.href = '" + fromPage + ".jsp'; }, 2000);");
            out.println("</script>");
        }

        // Load customers for the table
        List<Map<String, String>>custList = new ArrayList<>();
        ResultSet rs = conn.createStatement().executeQuery("SELECT * FROM Customers ORDER BY CustomerID DESC");
        while(rs.next()){
            Map<String, String> c = new HashMap<>();
            c.put("id", rs.getString("CustomerID"));
            c.put("name", rs.getString("CustomerName"));
            c.put("phone", rs.getString("ContactNumber"));
            c.put("email", rs.getString("Email"));
            custList.add(c);
        }

        
        request.setAttribute("custList", custList);
        conn.close();
    } catch (Exception e) { message = "Error: " + e.getMessage(); }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Customer Registry</title>
    <link rel="stylesheet" href="UserCred.css">
</head>
<body>
    <div class="user-container">
        <h2>Register New Customer</h2>
        <% if(!message.isEmpty()){ %><p style="text-align:center; color:green;"><%=message%></p><% } %>
        
        <form method="post" action="custcreate.jsp?from=<%= fromPage %>">
            <input type="hidden" name="action" value="save">

            <div class="form-group">
                <label>Customer Name</label>
                <input type="text" name="custName" class="input" required>
            </div>
            <div class="form-group">
                <label>Phone Number</label>
                <input type="text" name="custPhone" class="input">
            </div>
            <div class="form-group">
                <label>Email</label>
                <input type="text" name="email" class="input">
            </div> 
            
            <button type="submit" style="width:100%; padding:10px; background:black; color:white; border-radius:8px; cursor:pointer; margin-top:10px;">Save Customer</button>
            
            <div style="text-align:center; margin-top:15px;">
                <a href="<%= fromPage %>.jsp" style="text-decoration:none; color:#666; font-size:13px;">&larr; Cancel and Return</a>
            </div>
        </form>

        <table class="user-table" style="margin-top:20px;">
            <thead>
                <tr><th>ID</th><th>Name</th><th>Phone</th><th>Email</th></tr>
            </thead>
            <tbody>
                <% 
                List<Map<String,String>> list = (List<Map<String,String>>)request.getAttribute("custList");
                if(list != null) {
                    for(Map<String,String> c : list) { %>
                    <tr>
                        <td><%= c.get("id") %></td>
                        <td><%= c.get("name") %></td>
                        <td><%= c.get("phone") %></td>
                        <td><%= (c.get("email") != null) ? c.get("email") : "" %></td>
                    </tr>
                <%  } 
                } %>
            </tbody>
        </table>
    </div>
</body>
</html>