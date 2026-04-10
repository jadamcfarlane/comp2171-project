<%@ page import="java.sql.*, java.util.*" %>

<%
HttpSession sessionObj = request.getSession(false);

if (sessionObj == null || sessionObj.getAttribute("username") == null) {
    response.sendRedirect("login.jsp");
    return;
}

/* DATABASE CONNECTION */

String connStr =
"jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";

/* FORM VALUES */

String action = request.getParameter("action");
String userId = request.getParameter("userId");
String startDate = request.getParameter("startDate");
String endDate = request.getParameter("endDate");

/* DATA STRUCTURES */

List<String[]> users = new ArrayList<>();
List<Map<String,Object>> activities = new ArrayList<>();

try {
    Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");

    Connection conn = DriverManager.getConnection(connStr);

    /* LOAD USERS */
    Statement stmt = conn.createStatement();
    ResultSet rsUsers = stmt.executeQuery("SELECT UserID, UserName FROM Users");

    while(rsUsers.next()) {
        users.add(new String[]{
            rsUsers.getString("UserID"),
            rsUsers.getString("UserName")
        });
    }

    /* LOAD ACTIVITIES INCLUDING FAILED LOGINS */
    String sql =
        "SELECT ActivityTime, UserName, ActivityType, ActivityDescription, UserID " +
        "FROM UserLoginActivity WHERE 1=1";

    if(userId != null && !userId.isEmpty()) {
        sql += " AND UserID=?";
    }

    if(startDate != null && !startDate.isEmpty()) {
        sql += " AND ActivityTime >= ?";
    }

    if(endDate != null && !endDate.isEmpty()) {
        sql += " AND ActivityTime <= ?";
    }

    sql += " ORDER BY ActivityTime DESC";

    PreparedStatement ps = conn.prepareStatement(sql);

    int index = 1;
    if(userId != null && !userId.isEmpty()) {
        ps.setInt(index++, Integer.parseInt(userId));
    }

    if(startDate != null && !startDate.isEmpty()) {
        ps.setString(index++, startDate);
    }

    if(endDate != null && !endDate.isEmpty()) {
        ps.setString(index++, endDate);
    }

    ResultSet rs = ps.executeQuery();

    while(rs.next()) {
        Map<String,Object> row = new HashMap<>();
        row.put("time", rs.getString("ActivityTime"));
        row.put("user", rs.getString("UserName"));
        row.put("type", rs.getString("ActivityType"));
        row.put("desc", rs.getString("ActivityDescription"));
        activities.add(row);
    }



    conn.close();

} catch(Exception e) {
    e.printStackTrace();
}
%>

<!DOCTYPE html>
<html>
<head>
    <title>User Activity Report</title>
    <link rel="stylesheet" href="UserActivity.css">
</head>
<body>

<header>
    <ul class="navigation">
        <li><a href="MPOS.jsp">Dashboard</a></li>
        <li><a href="usercred.jsp">User Management</a></li>
        <li><a href="logout.jsp?from= User Activity">Sign Out</a></li>
    </ul>
</header>

<div class="main">
    <h1>User Activity Report</h1>

    <div class="filter-section">
        <form method="get" action="useractivity.jsp">
            <label>User:</label>
            <select name="userId">
                <option value="">All Users</option>
                <% for(String[] u : users) { %>
                    <option value="<%= u[0] %>" <%= (userId != null && userId.equals(u[0])) ? "selected" : "" %>>
                        <%= u[1] %>
                    </option>
                <% } %>
            </select>

            <label>Start Date:</label>
            <input type="date" name="startDate" value="<%= startDate != null ? startDate : "" %>">

            <label>End Date:</label>
            <input type="date" name="endDate" value="<%= endDate != null ? endDate : "" %>">

            <button type="submit" name="action" value="filter" class="btnsubmit">Filter</button>
            <button type="submit" name="action" value="refresh" class="btnsubmit">Refresh</button>
        </form>
    </div>

    <table class="grid-items">
        <thead>
            <tr>
                <th>Time</th>
                <th>User</th>
                <th>Activity Type</th>
                <th>Description</th>
            </tr>
        </thead>
        <tbody>
            <% if (activities != null && !activities.isEmpty()) {
                for (Map<String,Object> row : activities) { %>
                <tr>
                    <td><%= row.get("time") %></td>
                    <td><strong><%= row.get("user") %></strong></td>
                    <td><%= row.get("type") %></td>
                    <td><%= row.get("desc") %></td>
                </tr>
            <% } } else { %>
                <tr>
                    <td colspan="4" style="text-align:center; padding: 20px;">No activity logs found.</td>
                </tr>
            <% } %>
        </tbody>
    </table>
</div>

</body>
</html>