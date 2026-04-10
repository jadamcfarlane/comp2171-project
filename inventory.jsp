<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%

String connStr="jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";

Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
Connection con=DriverManager.getConnection(connStr);

String message="";

String itemId=request.getParameter("itemId");
String quantity=request.getParameter("quantity");

if(itemId!=null && quantity!=null){
    int id=Integer.parseInt(itemId);
    int qty=Integer.parseInt(quantity);

    PreparedStatement ps=con.prepareStatement(
    "UPDATE Item SET Stock=Stock+?, LastAddedQty=? WHERE ItemID=?");
    ps.setInt(1,qty);
    ps.setInt(2,qty);
    ps.setInt(3,id);
    ps.executeUpdate();

    PreparedStatement history=con.prepareStatement(
    "INSERT INTO StockHistory(ItemID,QtyAdded) VALUES(?,?)");
    history.setInt(1,id);
    history.setInt(2,qty);
    history.executeUpdate();

    message="Stock successfully added!";
}

Statement stmt=con.createStatement();
ResultSet rs1=stmt.executeQuery("SELECT ISNULL(SUM(Stock),0) FROM Item");
rs1.next();
int totalItems=rs1.getInt(1);

ResultSet rs2=stmt.executeQuery("SELECT COUNT(*) FROM Item");
rs2.next();
int uniqueSKU=rs2.getInt(1);

ResultSet rs3=stmt.executeQuery("SELECT COUNT(*) FROM Item WHERE Stock<=10");
rs3.next();
int lowStock=rs3.getInt(1);

ResultSet rs4=stmt.executeQuery("SELECT ISNULL(SUM(Stock*Price),0) FROM Item");
rs4.next();
double inventoryValue=rs4.getDouble(1);

List<Map<String,String>> dropdownItems=new ArrayList<>();
PreparedStatement drop=con.prepareStatement("SELECT ItemID,ItemName FROM Item ORDER BY ItemName");
ResultSet dr=drop.executeQuery();
while(dr.next()){
    Map<String,String> row=new HashMap<>();
    row.put("id",dr.getString("ItemID"));
    row.put("name",dr.getString("ItemName"));
    dropdownItems.add(row);
}

List<Map<String,Object>> items=new ArrayList<>();
PreparedStatement all=con.prepareStatement("SELECT ItemID, ItemName,Stock,LastAddedQty,LastSoldQty,(Stock*Price) AS Value FROM Item");
ResultSet ai=all.executeQuery();
while(ai.next()){
    Map<String,Object> row=new HashMap<>();
    row.put("ItemID", ai.getString("ItemID")); 
    row.put("name",ai.getString("ItemName"));
    row.put("stock",ai.getInt("Stock"));
    row.put("added",ai.getInt("LastAddedQty"));
    row.put("sold",ai.getInt("LastSoldQty"));
    row.put("value",ai.getDouble("Value"));
    items.add(row);
}

List<Map<String,Object>> lowItems=new ArrayList<>();
PreparedStatement low=con.prepareStatement("SELECT ItemName,Stock FROM Item WHERE Stock<=10");
ResultSet li=low.executeQuery();
while(li.next()){
    Map<String,Object> row=new HashMap<>();
    row.put("name",li.getString("ItemName"));
    row.put("stock",li.getInt("Stock"));
    lowItems.add(row);
}
%>

<!DOCTYPE html>
<html>
<head>
    <title>Inventory Overview</title>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <link rel="stylesheet" href="Inventory.css"/>
</head>
<body>

<header>
    <ul class="navigation">
        <li><a href="MPOS.jsp">Dashboard</a></li>
        <li><a href="Sales.jsp">Sales</a></li>
        <li><a href="logout.jsp?from=Inventory">Sign Out</a></li>
    </ul>
</header>

<main class="dashboard">
    <header class="dashboard-header">
        <h1 class="dashboard-title">Inventory Overview</h1>
        <p style="color: var(--accent); font-weight: bold;"><%=message%></p>
    </header>

    <div class="add-stock-box">
        <h2 style="margin-bottom: 15px; font-size: 18px;">Add Stock</h2>
        <form method="post" style="display: flex; gap: 10px; flex-wrap: wrap;">
            <select name="itemId" class="input-box" style="flex: 2; min-width: 200px;">
                <% for(Map<String,String> item:dropdownItems){ %>
                    <option value="<%=item.get("id")%>"><%=item.get("name")%></option>
                <% } %>
            </select>
            <input type="number" name="quantity" class="input-box" placeholder="Quantity" min="1" required style="flex: 1;">
            <button type="submit" class="btn-add">Add Stock</button>
        </form>
    </div>

    <section class="kpi-grid kpi-grid-2x2">

        <article class="card kpi-large">
            <div class="card-title">Total Items in Stock</div>
            <div class="card-value"><%=totalItems%></div>
            
            <div class="inventory-summary">
                <div class="card-title" style="margin-top: 10px;">Inventory Stock Summary</div>
                <% for(Map<String,Object> item:items){ 
                    int s = (int)item.get("stock");
                    String cls = (s <= 5) ? "stock-critical" : (s <= 15) ? "stock-low" : "stock-safe";
                %>
                    <div class="stock-card <%=cls%>" style="display: block; width: 100%; margin: 8px 0;">
                        <div class="stock-title"><%=item.get("name")%></div>
                        <div class="stock-qty">Remaining: <%=item.get("stock")%></div>
                        <div class="stock-meta">
                            Added: <b><%=item.get("added")%></b> | 
                            Sold: <b><%=item.get("sold")%></b><br/>
                            Value: <b>$<%=String.format("%.2f",item.get("value"))%></b>
                        </div>
                    </div>
                <% } %>
            </div>
        </article>

        <article class="card kpi-large">
            <div class="card-title">Unique SKUs</div>
            <div class="card-value"><%=uniqueSKU%></div>
            <div class="inventory-summary">
                    <% for(Map<String, Object> item : items) { %>
                        <div class="stock-card stock-safe" style="display: block; width: 100%; margin: 8px 0;">
                            <div class="stock-title">
                                SKU: <%= item.get("ItemID") %> - <%= item.get("name") %>
                            </div>
                        </div>
                    <% } %>
                </div>
        </article>

        <article class="card kpi-large">
            <div class="card-title" style="color: #e74c3c;">Low Stock Items</div>
            <div class="card-value" style="color: #e74c3c;"><%=lowStock%></div>
            <div class="inventory-summary">
                <% for(Map<String,Object> item:lowItems){ %>
                    <div class="stock-card stock-critical" style="display: block; width: 100%; margin: 8px 0;">
                        <div class="stock-title"><%=item.get("name")%></div>
                        <div class="stock-qty">Remaining: <%=item.get("stock")%></div>
                    </div>
                <% } %>
            </div>
        </article>

        <article class="card kpi-large">
            <div class="card-title">Inventory Value</div>
            <div class="card-value">$<%=String.format("%,.2f",inventoryValue)%></div>
            <div class="card-subrow"><span>+0%</span></div>
            <div class="card-compare">vs previous 30 days</div>
        </article>

    </section>
</main>

</body>
</html>