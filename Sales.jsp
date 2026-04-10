<%@ page import="java.sql.*, java.util.*, java.time.*, java.time.format.TextStyle, java.util.Locale" %>

<%
HttpSession sessionObj = request.getSession(false);

if (sessionObj == null || sessionObj.getAttribute("username") == null) {
    response.sendRedirect("login.jsp");
    return;
}

String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";

int currentMonth = LocalDate.now().getMonthValue();
int currentYear = Year.now().getValue();

int month = (request.getParameter("month") != null) ? Integer.parseInt(request.getParameter("month")) : currentMonth;
int year = (request.getParameter("year") != null) ? Integer.parseInt(request.getParameter("year")) : currentYear;

int totalAccounts = 0;
int orders = 0;
double revenue = 0;
double growth = 0;

List<Map<String,Object>> salesData = new ArrayList<>();
double[] monthlyRevenue = new double[12];
double[] hourlyRevenue = new double[24];
for(int i=0; i<12; i++) monthlyRevenue[i] = 0.0;
List<String> topProducts = new ArrayList<>();
List<Integer> topQty = new ArrayList<>();
List<String> employeeNames = new ArrayList<>();
List<Double> employeeRevenue = new ArrayList<>();

try {
    Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
    Connection conn = DriverManager.getConnection(connStr);

    //Total Customers
    PreparedStatement ps1 = conn.prepareStatement("SELECT COUNT(DISTINCT ReceiptNo) FROM Sales WHERE MONTH(DateSold)=? AND YEAR(DateSold)=?");
    ps1.setInt(1, month);
    ps1.setInt(2,year);
    ResultSet rs1 = ps1.executeQuery();
    if(rs1.next()){ totalAccounts = rs1.getInt(1); }

    //Total Number of Sales
    PreparedStatement ps2 = conn.prepareStatement("SELECT COUNT(SaleID) FROM Sales WHERE MONTH(DateSold)=? AND YEAR(DateSold)=?");
    ps2.setInt(1, month);
    ps2.setInt(2,year);
    ResultSet rs2 = ps2.executeQuery();
    if(rs2.next()){ orders = rs2.getInt(1); }

    //Business Growth
    int prevMonth = (month == 1) ? 12 : month - 1;
    int prevYear = (month == 1) ? year - 1 : year;
    PreparedStatement ps3 = conn.prepareStatement("SELECT COUNT(*) FROM Sales WHERE MONTH(DateSold)=? AND YEAR(DateSold)=?");
    ps3.setInt(1, prevMonth);
    ps3.setInt(2, prevYear);
    ResultSet rs3 = ps3.executeQuery();
    int prevOrders = 0;
    if(rs3.next()){ prevOrders = rs3.getInt(1); }
    if(prevOrders != 0){ 
        growth = ((double)(orders - prevOrders) / prevOrders) * 100; 
        } else{
            growth = 0.0;
        }

    //Total Revenue
    PreparedStatement ps4 = conn.prepareStatement("SELECT ISNULL(SUM(Total),0) FROM Sales WHERE MONTH(DateSold)=? AND YEAR(DateSold)=?");
    ps4.setInt(1, month);
    ps4.setInt(2, year);
    ResultSet rs4 = ps4.executeQuery();
    if(rs4.next()){ revenue = rs4.getDouble(1); }

    //Sales Report Table
    PreparedStatement ps5 = conn.prepareStatement(
    "SELECT i.ItemName, " +
    "SUM(s.Qty) AS TotalSold, " +
    "SUM(s.Total) AS ItemRevenue " +
    "FROM Sales s " +
    "INNER JOIN Item i ON s.ItemID = i.ItemID " +
    "WHERE MONTH(s.DateSold)=? AND YEAR(s.DateSold)=? " +
    "GROUP BY i.ItemName"
    );
    ps5.setInt(1, month);
    ps5.setInt(2, year);
    ResultSet rs5 = ps5.executeQuery();
    salesData.clear();
    while(rs5.next()){
        Map<String,Object> row = new HashMap<>();
        row.put("ItemName", rs5.getString("ItemName"));
        row.put("TotalSold", rs5.getInt("TotalSold"));
        row.put("Revenue", rs5.getDouble("ItemRevenue"));
        salesData.add(row);
    }

    //Peak Sales Hour
    PreparedStatement psPeak = conn.prepareStatement(
        "SELECT DATEPART(HOUR, DateSold) AS SalesHour, SUM(Total) AS HourlyTotal " +
        "FROM Sales WHERE MONTH(DateSold)=? AND YEAR(DateSold)=? " +
        "GROUP BY DATEPART(HOUR, DateSold) ORDER BY SalesHour"
    );
    psPeak.setInt(1, month);
    psPeak.setInt(2, year);
    ResultSet rsPeak = psPeak.executeQuery();

    while(rsPeak.next()){
        int hour = rsPeak.getInt("SalesHour");
        hourlyRevenue[hour] = rsPeak.getDouble("HourlyTotal");
}

    //Bestselling Items
    PreparedStatement psTop = conn.prepareStatement(
        "SELECT TOP 5 i.ItemName, SUM(s.Qty) AS QtySold " +
        "FROM Sales s " +
        "JOIN Item i ON s.ItemID=i.ItemID " +
        "WHERE MONTH(s.DateSold) = ? AND YEAR(s.DateSold)=? " +
        "GROUP BY i.ItemName " +
        " ORDER BY QtySold DESC"
    );
    psTop.setInt(1, month);
    psTop.setInt(2, year);
    ResultSet rsTop = psTop.executeQuery();

    topProducts.clear(); 
    topQty.clear();
    while(rsTop.next()){
        topProducts.add(rsTop.getString("ItemName"));
        topQty.add(rsTop.getInt("QtySold"));
    }

    //Monthly Revenue
    PreparedStatement psTrend = conn.prepareStatement(
        "SELECT MONTH(DateSold) AS MonthNum, SUM(Total) AS Revenue " +
        "FROM Sales WHERE YEAR(DateSold)=? GROUP BY MONTH(DateSold)"
    );
    psTrend.setInt(1, year);
    ResultSet rsTrend = psTrend.executeQuery();
    while(rsTrend.next()){
    int mIdx = rsTrend.getInt("MonthNum") - 1; 
    if (mIdx >= 0 && mIdx < 12) {
        monthlyRevenue[mIdx] = rsTrend.getDouble("Revenue");
    }
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
        <li><a href="logout.jsp?from=Sales">Sign Out</a></li>
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

            <select name="year" class="month-select" onchange="this.form.submit()">
            <% 
                int selectedYear = (request.getParameter("year") != null) ? Integer.parseInt(request.getParameter("year")) : currentYear;
                for (int y = currentYear; y >= currentYear - 5; y--) { 
            %>
                <option value="<%=y%>" <%= (y == selectedYear ? "selected" : "") %>><%=y%></option>
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
            <h2>Monthly Revenue Trend (<%= year %>)</h2>
            <canvas id="salesChart"></canvas>
        </article>
    
    <article class="card">
            <h2>Peak Hours</h2>
            <div class="chart-container" style="position: relative; height:300px; width:100%;">
                <canvas id="peakHoursChart"></canvas>
            </div>
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
    var peakData = [<% for(int i=0; i<24; i++){ out.print(hourlyRevenue[i] + (i<23?",":"")); } %>];
    var topProdLabels = [<% for(int i=0;i<topProducts.size();i++){ out.print("'"+topProducts.get(i)+"'" + (i<topProducts.size()-1?",":"")); } %>];
    var topProdQty = [<% for(int i=0;i<topQty.size();i++){ out.print(topQty.get(i) + (i<topQty.size()-1?",":"")); } %>];

    if (annualRevenue.every(item => item === 0)) {
    console.log("No data available for the year <%= year %>");
    }
    
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
        options: { 
            indexAxis: 'y'} 
        
    });

    new Chart(document.getElementById("peakHoursChart"), {
        type: 'line',
        data: {
            labels: ["12am", "1am", "2am", "3am", "4am", "5am", "6am", "7am", "8am", "9am", "10am", "11am", 
                     "12pm", "1pm", "2pm", "3pm", "4pm", "5pm", "6pm", "7pm", "8pm", "9pm", "10pm", "11pm"],
            datasets: [{
                label: 'Revenue ($)',
                data: peakData,
                borderColor: '#f59e0b', 
                backgroundColor: 'rgba(245, 158, 11, 0.2)',
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            plugins: {
                title: { display: true, text: 'Sales Heatmap by Hour' }
            },
            scales: {
                y: { beginAtZero: true }
            }
        }
    });

</script>

</body>
</html>
