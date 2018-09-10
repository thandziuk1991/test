library(chron)

setwd("Y:/Workspace/R projects/3rd Pivot Scanner/")
load("today_data.RData")

holidays = read.csv("Y:/Workspace/R projects/Price Index/Historical_Holidays.csv")
holidays = as.character(as.Date(holidays[,1],"%m/%d/%Y"))
yest = ifelse(chron::is.weekend(Sys.Date() - 1),as.character(Sys.Date() - 3),as.character(Sys.Date() - 1)) 


if(Sys.time() > strptime("05:00","%H:%M") && Sys.time() < strptime("15:30","%H:%M") && !chron::is.weekend(Sys.Date()) && !(yest %in% holidays)){
  
  library(openxlsx)
  library(RMySQL)
  library(RQuantLib)
  library(combinat)
  library(zoo)
  library(RDCOMClient)
  library(chron)
  library(jrvFinance)
  library(MASS)
  library(r2tt)
  library(httr)
  library(jsonlite)
  library(plyr)
  library(lubridate)
  library(stringr)
  
  selectEnvironment("SIM")
  
  options(digits = 12)
  options(scipen=999)
  options(stringsAsFactors = F)
  
  
  for(cons in dbListConnections(MySQL())){
    dbDisconnect(cons)
  }
  dbListConnections(MySQL())
  
  mydb = dbConnect(MySQL(), 
                   user='root', 
                   password='Taras25031991', 
                   dbname='hgt_database', 
                   host='10.128.135.156')
  
  rs = dbSendQuery(mydb, "select * from 3rd_pivot")  ###read from database
  inPivot = fetch(rs, n=-1)

  ############################################################# MAIN  ##############################################

  if(initializedData){
    
    data = getTops(symbolDataFrame)
    
    data = data[,symbolDataFrame[,"symbol"]]
    prices = as.numeric(data["bid",])
    
    prices = t(as.data.frame(prices))
    colnames(prices) = c(symbolDataFrame[,"product"])
    
    symbols = colnames(prices)
    
    somethingChanged = F
    
    for(symbol in symbols){
      
      divisor = getDivisor(symbol)
      price = prices[,symbol]/divisor
      symbolBbg = pointValue[which(pointValue[,"Symbol"] %in% symbol),"Symbol Bbg"]
      
       if(!is.na(price)){
        
        support3 = as.numeric(pivotTable[which(pivotTable[,"Symbol"] %in% symbol),"Support 3"])
        resistance3 = as.numeric(pivotTable[which(pivotTable[,"Symbol"] %in% symbol),"Resistance 3"])
        
        if( (price >= resistance3 || price <= support3) && !(inPivot[which(inPivot[,"Symbol"] %in% symbolBbg),"InPivot"] == TRUE) ){
          inPivot[which(inPivot[,"Symbol"] %in% symbolBbg),"InPivot"] = TRUE
          somethingChanged = T
          
          leadContract = symbolDataFrame[which(symbolDataFrame[,"product"] %in% symbol),"symbol"]
          leadContract = paste0(symbolBbg,substr(leadContract,nchar(leadContract)-1,nchar(leadContract)))
          
          if(price >= resistance3){
            
            finalOutput = cbind(leadContract,"Crossed R3")
            
            sendEmail(finalOutput)
          }
          
          if(price <= support3){
            
            finalOutput = cbind(leadContract,"Crossed S3")
            
            sendEmail(finalOutput)
          }
          
          
        }
        
      }
      
    }
    
    
    if(somethingChanged){
      inPivot = cbind(inPivot[,1:2],Sys.time())
      dbWriteTable(mydb,name = "3rd_pivot", value = as.data.frame(inPivot),overwrite = TRUE,append = FALSE,row.names = FALSE,col.names = F)
    }
    
    save.image("today_data.RData")
    
  }else{
    
    for(cons in dbListConnections(MySQL())){
      dbDisconnect(cons)
    }
    dbListConnections(MySQL())
    
    mydb = dbConnect(MySQL(), 
                     user='root', 
                     password='Taras25031991', 
                     dbname='hgt_database', 
                     host='10.128.135.156')
    
    getExch = function(symbol){
      if(symbol %in% c("ES","6E","6B","6J","6A","6C","NG","CL","RB","SI","HG","GC","ZT","ZF","ZN","ZB","UB","ZC","ZS","ZW","TN","6S","NQ","NIY","YM")){
        exch = "CME"
      }else if(symbol %in% c("FGBS","FGBM","FGBL","FGBX","FDAX","FBTP","FOAT","FESX")){
        exch = "Eurex"
      }else if(symbol %in% c("R","G","Z")){
        exch = "ICE_IPE"
      }
      return(exch)
    }
    
    getType = function(symbol){
      type = "FUTURE"
    }
    
    getDivisor = function(symbol){
      divMult100 = c("ZC","ZW","ZS")
      div1Symbols = c("ZT","ZF","ZN","ZB","UB","FGBL","FGBX","G","TN","FOAT","FBTP","FESX","NIY","FDAX","Z","YM")
      div10Symbols = c("GC")
      div100Symbols = c("CL","RB","ES","6J","6A","6C","GE5","GE9","GE13","NQ","6S","6B","HG")
      div1KSymbols = c("NG","SI")
      div10KSymbols = c("6E")
      
      if(length(which(divMult100 %in% symbol))!=0){
        divisor = 0.01
      }
      if(length(which(div1Symbols %in% symbol))!=0){
        divisor = 1
      }
      if(length(which(div10Symbols %in% symbol))!=0){
        divisor = 10
      }
      if(length(which(div100Symbols %in% symbol))!=0){
        divisor = 100
      }
      if(length(which(div1KSymbols %in% symbol))!=0){
        divisor = 1000
      }
      if(length(which(div10KSymbols %in% symbol))!=0){
        divisor = 10000
      }
      
      return(divisor)
    }
    
    sendEmail = function(finalOutput){
      
      emails = c("thandziuk@dvtrading.co","cgardner@dvtrading.co","bhughes@dvtrading.co","gdeppen@dvtrading.co")
      
      OutApp <- COMCreate("Outlook.Application")
      outMail = OutApp$CreateItem(0)
      outMail[["To"]] =paste(emails,collapse = ";")
      outMail[["body"]] = ""
      
      outMail[["subject"]] = paste0(finalOutput,"")
      #3outMail[["Attachments"]]$Add(paste("Y:\\Workspace\\R projects\\3rd Pivot Scanner\\trades.csv",sep = ""))
      outMail$Send()
      
    }
    
    
    ###############################################################  MAIN ##########################################
    rs = dbSendQuery(mydb, "select * from lead_month_contract")  ###read from database
    leadMonth = fetch(rs, n=-1)
    
    rs = dbSendQuery(mydb, "select * from point_value")  ###read from database
    pointValue = fetch(rs, n=-1)
    
    symbols = c("ES","6E","6B","6J","6A","6C","NG","CL","RB","SI","HG","GC","ZT","ZF","ZN","ZB","UB","ZC","ZS","ZW","TN","6S","NQ","NIY","YM",
                "FGBL","FGBX","FDAX","FBTP","FOAT","FESX",
                "R","Z")
    
    today = ifelse(Sys.time() >= strptime("17:00","%H:%M") && Sys.time() < strptime("00:00","%H:%M"),as.character(Sys.Date()+1),as.character(Sys.Date()))
    
    for(symbol in symbols){
      
      exch = getExch(symbol)
      type = getType(symbol)
      
      symbolBbg = pointValue[which(pointValue[,"Symbol"] %in% symbol),"Symbol Bbg"]
      leadContract = leadMonth[which(leadMonth[,1] %in% as.character(Sys.Date())),symbolBbg]
      leadContract = paste0(symbol,substr(leadContract,nchar(leadContract)-1,nchar(leadContract)))
      symbolLine = cbind(leadContract,symbol,type,exch)
      
      if(exists("symbolDataFrame")){
        symbolDataFrame = rbind(symbolDataFrame,symbolLine)
      }else{
        symbolDataFrame = symbolLine
      }
      
      
      ################## PIVOT CALCULATION
      tDay = Sys.Date()
      inRoll = F
      
      yest = ifelse(chron::is.weekend(tDay - 1),as.character(tDay - 3),as.character(tDay - 1))
      
      symbolBbg  = pointValue[which(pointValue[,"Symbol"] %in% symbol),"Symbol Bbg"]
      divisor = getDivisor(symbol)
      tickSize = as.numeric(pointValue[which(pointValue[,"Symbol"] %in% symbol),"Tick Size"])
      
      leadContract = leadMonth[which(leadMonth[,1] %in% as.character(Sys.Date())),symbolBbg]
      if(leadContract != leadMonth[which(leadMonth[,1] %in% as.character(Sys.Date()))-1,symbolBbg]){
        inRoll = T
      }
      
      rs = dbSendQuery(mydb, paste0("select * from futures_",symbolBbg))  ###read from database
      closes = fetch(rs, n=-1)
      
      if(inRoll){
        rs = dbSendQuery(mydb, paste0("select * from minute_data_",symbol,"2"))  ###read from database
        minute_data = fetch(rs, n=-1)
      }else{
        rs = dbSendQuery(mydb, paste0("select * from minute_data_",symbol,"_1719"))  ###read from database
        minute_data = fetch(rs, n=-1)
      }
      if(nchar(leadContract) == 3){
        leadContract = paste(substr(leadContract,1,1),substr(leadContract,2,3))
      }
      
      yestData = minute_data[,yest]/divisor
      
      if(!all(is.na(yestData))){
        yestClose = as.numeric(closes[which(closes[,1] %in% yest),leadContract])
        yestLow = min(yestData,na.rm = T)
        yestHigh = max(yestData,na.rm = T)
        
        pivot = round(((yestClose + yestHigh + yestLow)/3)/tickSize)*tickSize
        resistance1 = round((2*pivot - yestLow)/tickSize)*tickSize
        support1 = round((2*pivot - yestHigh)/tickSize)*tickSize
        
        resistance2 = round(((pivot - support1) + resistance1)/tickSize)*tickSize
        support2 = round((pivot - (resistance1 - support1))/tickSize)*tickSize
        
        resistance3 = round(((pivot - support2) + resistance2)/tickSize)*tickSize
        support3 = round((pivot - (resistance2 - support2))/tickSize)*tickSize
        
      }
      symbolPivot = cbind(symbol,support1,support2,support3,resistance1,resistance2,resistance3)
      
      if(exists("pivotTable")){
        pivotTable = rbind(pivotTable,symbolPivot)
      }else{
        pivotTable = symbolPivot
      }
      
    }
    
    symbolDataFrame = as.data.frame(symbolDataFrame)
    colnames(symbolDataFrame) = c("symbol","product","type","exchange")
    
    pivotTable = as.data.frame(pivotTable)
    colnames(pivotTable) = c("Symbol","Support 1","Support 2","Support 3","Resistance 1","Resistance 2","Resistance 3")
    
    write.csv(pivotTable,paste0("Daily Pivots/pivotTable_",Sys.Date(),".csv"),row.names = F)
    
    initializedData = T
    
    save.image("today_data.RData")
    
    pivotTableTemp = cbind(pivotTable,Sys.time())
    
    dbWriteTable(mydb,name = "daily_pivots", value = as.data.frame(pivotTableTemp),overwrite = TRUE,append = FALSE,row.names = FALSE,col.names = F)
    
    remove(pivotTableTemp)
    
  }

  
  
}else if(Sys.time() > strptime("15:30","%H:%M") && Sys.time() < strptime("15:32","%H:%M") && !is.weekend(Sys.Date())){
  
  ####### RESET
  
  if(initializedData){
    library(openxlsx)
    library(RMySQL)
    library(RQuantLib)
    library(combinat)
    library(zoo)
    library(RDCOMClient)
    
    options(digits = 12)
    options(scipen=999)
    options(stringsAsFactors = F)
    
    
    for(cons in dbListConnections(MySQL())){
      dbDisconnect(cons)
    }
    dbListConnections(MySQL())
    
    mydb = dbConnect(MySQL(), 
                     user='root', 
                     password='Taras25031991', 
                     dbname='hgt_database', 
                     host='10.128.135.156')
    
    rs = dbSendQuery(mydb, "select * from 3rd_pivot")  ###read from database
    inPivot = fetch(rs, n=-1)
    
    setwd("Y:/Workspace/R projects/3rd Pivot Scanner/")
    
    inPivot = inPivot[,1:2]
    inPivot[,2] = "FALSE"
    
    initializedData = F
    remove(symbolDataFrame)
    remove(pivotTable)
    
    save.image("today_data.RData")
    
    dbWriteTable(mydb,name = "3rd_pivot", value = as.data.frame(inPivot),overwrite = TRUE,append = FALSE,row.names = FALSE,col.names = F)
  }
  

}





