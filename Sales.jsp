<%@ page import="java.sql.*, java.util.*, java.time.*, java.time.format.TextStyle, java.util.Locale" %>

<%
HttpSession sessionObj = request.getSession(false);

if (sessionObj == null || sessionObj.getAttribute("username") == null) {
    response.sendRedirect("login.jsp");
    return;
}

String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";

int month;
String m = request.getParameter("month");

if (m == null) {
    month = LocalDate.now().getMonthValue();
} else {
    month = Integer.parseInt(m);
}

int totalAccounts = 0;
int orders = 0;
double revenue = 0;
double growth = 0;

List<Map<String,Object>> salesData = new ArrayList<>();
double[] monthlyRevenue = new double[12];
List<String> topProducts = new ArrayList<>();
List<Integer> topQty = new ArrayList<>();
List<String> employeeNames = new ArrayList<>();
List<Double> employeeRevenue = new ArrayList<>();

try {
    Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
    Connection conn = DriverManager.getConnection(connStr);

    PreparedStatement ps1 = conn.prepareStatement("SELECT COUNT(DISTINCT ReceiptNo) FROM Sales WHERE MONTH(DateSold)=?");
    ps1.setInt(1, month);
    ResultSet rs1 = ps1.executeQuery();
    if(rs1.next()){ totalAccounts = rs1.getInt(1); }

    PreparedStatement ps2 = conn.prepareStatement("SELECT COUNT(SaleID) FROM Sales WHERE MONTH(DateSold)=?");
    ps2.setInt(1, month);
    ResultSet rs2 = ps2.executeQuery();
    if(rs2.next()){ orders = rs2.getInt(1); }

    int prevMonth = (month == 1) ? 12 : month - 1;
    PreparedStatement ps3 = conn.prepareStatement("SELECT COUNT(*) FROM Sales WHERE MONTH(DateSold)=?");
    ps3.setInt(1, prevMonth);
    ResultSet rs3 = ps3.executeQuery();
    int prevOrders = 0;
    if(rs3.next()){ prevOrders = rs3.getInt(1); }
    if(prevOrders != 0){ growth = ((double)(orders - prevOrders) / prevOrders) * 100; }

    PreparedStatement ps4 = conn.prepareStatement("SELECT ISNULL(SUM(Total),0) FROM Sales WHERE MONTH(DateSold)=?");
    ps4.setInt(1, month);
    ResultSet rs4 = ps4.executeQuery();
    if(rs4.next()){ revenue = rs4.getDouble(1); }

    PreparedStatement ps5 = conn.prepareStatement(
    "SELECT i.ItemName, ISNULL(u.UserName, 'System/Guest') AS UserName, " +
    "SUM(s.Qty) AS TotalSold, SUM(s.Total) AS Revenue " +
    "FROM Sales s " +
    "JOIN Item i ON s.ItemID = i.ItemID " +
    "LEFT JOIN Users u ON s.UserID = u.UserID " + 
    "WHERE MONTH(s.DateSold)=? " +
    "GROUP BY i.ItemName, u.UserName"
    );
    ps5.setInt(1, month);
    ResultSet rs5 = ps5.executeQuery();
    while(rs5.next()){
        Map<String,Object> row = new HashMap<>();
        row.put("ItemName", rs5.getString("ItemName"));
        row.put("UserName", rs5.getString("UserName"));
        row.put("TotalSold", rs5.getInt("TotalSold"));
        row.put("Revenue", rs5.getDouble("Revenue"));
        salesData.add(row);
    }

    PreparedStatement psTop = conn.prepareStatement("SELECT TOP 5 i.ItemName, SUM(s.Qty) AS QtySold FROM Sales s JOIN Item i ON s.ItemID=i.ItemID GROUP BY i.ItemName ORDER BY QtySold DESC");
    ResultSet rsTop = psTop.executeQuery();
    while(rsTop.next()){
        topProducts.add(rsTop.getString("ItemName"));
        topQty.add(rsTop.getInt("QtySold"));
    }

    PreparedStatement psEmp = conn.prepareStatement(
    "SELECT ISNULL(u.UserName, 'Unknown') AS UserName, SUM(s.Total) AS Revenue " +
    "FROM Sales s " +
    "LEFT JOIN Users u ON s.UserID=u.UserID " +
    "WHERE MONTH(s.DateSold)=? " + 
    "GROUP BY u.UserName"
    );
    psEmp.setInt(1, month);
    ResultSet rsEmp = psEmp.executeQuery();
    while(rsEmp.next()){
        employeeNames.add(rsEmp.getString("UserName"));
        employeeRevenue.add(rsEmp.getDouble("Revenue"));
    }

    PreparedStatement psTrend = conn.prepareStatement("SELECT MONTH(DateSold) AS MonthNum, SUM(Total) AS Revenue FROM Sales GROUP BY MONTH(DateSold)");
    ResultSet rsTrend = psTrend.executeQuery();
    while(rsTrend.next()){
        monthlyRevenue[rsTrend.getInt("MonthNum")-1] = rsTrend.getDouble("Revenue");
    }

    conn.close();
}catch(Exception e){ e.printStackTrace(); }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Sales Dashboard</title>
    <link href="Sales.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>

<header>
    <ul class="navigation">
        <li><a href="MPOS.jsp">Dashboard</a></li>
        <li><a href="inventory.jsp">Inventory</a></li>
        <li><a href="Sales.jsp">Sales</a></li>
        <li><a href="login.jsp">Sign Out</a></li>
    </ul>
</header>

<main class="dashboard">
    <header class="dashboard-header">
        <h1>Sales Dashboard</h1>
        <form method="get" action="Sales.jsp">
            <select name="month" class="month-select" onchange="this.form.submit()">
                <% for (int i=1;i<=12;i++){
                    String name = Month.of(i).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                %>
                <option value="<%=i%>" <%= (i==month?"selected":"") %>><%=name%></option>
                <% } %>
            </select>
        </form>
    </header>

    <section class="kpi-grid">
        <div class="card"><h3>Total Accounts</h3><p><%= String.format("%,d", totalAccounts) %></p></div>
        <div class="card"><h3>Orders</h3><p><%= String.format("%,d", orders) %></p></div>
        <div class="card"><h3>Growth</h3><p><%= String.format("%.1f%%",growth) %></p></div>
        <div class="card"><h3>Revenue</h3><p>$<%= String.format("%,.2f",revenue) %></p></div>
    </section>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 20px;">
        <article class="card">
            <h2>Monthly Revenue Trend</h2>
            <canvas id="salesChart"></canvas>
        </article>
        <article class="card">
            <h2>Sales by Employee</h2>
            <canvas id="employeeChart"></canvas>
        </article>
    </div>

    <article class="card" style="margin-top: 20px;">
        <h2>Top 5 Best Selling Products</h2>
        <canvas id="topProductsChart" style="max-height: 300px;"></canvas>
    </article>

    <article class="card" style="margin-top: 20px;">
        <h2>Detailed Sales Report</h2>
        <table style="width:100%; border-collapse: collapse; margin-top: 15px;">
            <thead>
                <tr style="background: var(--bg); border-bottom: 2px solid #eee;">
                    <th style="text-align: left; padding: 12px;">Product Name</th>
                    <th style="text-align: left; padding: 12px;">Employee</th>
                    <th style="text-align: center; padding: 12px;">Qty</th>
                    <th style="text-align: right; padding: 12px;">Revenue</th>
                </tr>
            </thead>
            <tbody>
                <% if(salesData.isEmpty()) { %>
                    <tr><td colspan="4" style="text-align:center; padding: 30px;">No sales found for this month.</td></tr>
                <% } else {
                    for(Map<String,Object> row : salesData) { %>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 12px;"><%= row.get("ItemName") %></td>
                        <td style="padding: 12px; font-weight: bold; color: #3E8EDE;"><%= row.get("UserName") %></td>
                        <td style="padding: 12px; text-align: center;"><%= String.format("%,d", (Integer)row.get("TotalSold")) %></td>
                        <td style="padding: 12px; text-align: right; font-weight: 600;">$<%= String.format("%,.2f", (Double)row.get("Revenue")) %></td>
                    </tr>
                <% } } %>
            </tbody>
        </table>
    </article>
</main>

<script>
    var annualRevenue = [<% for(int i=0;i<12;i++){ out.print(monthlyRevenue[i] + (i<11?",":"")); } %>];
    var topProdLabels = [<% for(int i=0;i<topProducts.size();i++){ out.print("'"+topProducts.get(i)+"'" + (i<topProducts.size()-1?",":"")); } %>];
    var topProdQty = [<% for(int i=0;i<topQty.size();i++){ out.print(topQty.get(i) + (i<topQty.size()-1?",":"")); } %>];
    var empLabels = [<% for(int i=0;i<employeeNames.size();i++){ out.print("'"+employeeNames.get(i)+"'" + (i<employeeNames.size()-1?",":"")); } %>];
    var empData = [<% for(int i=0;i<employeeRevenue.size();i++){ out.print(employeeRevenue.get(i) + (i<employeeRevenue.size()-1?",":"")); } %>];

    new Chart(document.getElementById("salesChart"),{
        type:"line",
        data:{
            labels:["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
            datasets:[{label:"Revenue", data:annualRevenue, borderColor: '#3E8EDE', backgroundColor: 'rgba(62, 142, 222, 0.1)', fill: true, tension: 0.3}]
        }
    });

    new Chart(document.getElementById("topProductsChart"),{
        type:"bar",
        data:{
            labels:topProdLabels,
            datasets:[{label:"Quantity Sold", data:topProdQty, backgroundColor: '#16a34a'}]
        },
        options: { indexAxis: 'y' } 
    });

    new Chart(document.getElementById("employeeChart"), {
        type: 'doughnut',
        data: { 
            labels: empLabels, 
            datasets: [{ 
                data: empData, 
                backgroundColor: ['#3E8EDE', '#16a34a', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899'] 
            }]
        }
    });
</script>

</body>
</html>
