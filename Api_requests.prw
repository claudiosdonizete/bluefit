//---- Libraries
#INCLUDE "TOTVS.CH"
#INCLUDE "PROTHEUS.CH"
#INCLUDE "RESTFUL.CH"
#Include 'FWMVCDEF.ch'
#INCLUDE "TOPCONN.CH"
#INCLUDE "TBICONN.CH"

#define OPERATION_INSERT        3   
#define OPERATION_REVERT        5   

//---- Defines / Constants 
#Define msg_success "Requisição #IDREQUEST# criada com sucesso no mercado eletrônico! Para mais detalhes, consulte na plataforma."
#Define msg_error "ATENÇÃO!"+chr(13)+chr(10)+" Não foi possível processar a requisição #IDREQUEST# vinda do mercado eletronico. "+chr(13)+chr(10)+"Informe a mensagem abaixo para o seu depto de TI!"+chr(13)+chr(10)+" Motivo: "+alltochar(aReturn[2])
#Define Status_Aprovada 124
#Define DEF_JSON_CONTENT_TYPE   "application/json; charset=iso-8859-1"

//---- API Rest
WSRESTFUL MercadoEletronico DESCRIPTION "APIs de integração BlueFit x Mercado Eletrônico"
	WSDATA Page 		AS INTEGER OPTIONAL
	WSDATA PageSize		AS INTEGER OPTIONAL
    WSDATA Order        AS CHARACTER OPTIONAL
    WSDATA Fields       AS CHARACTER OPTIONAL

	WSMETHOD POST DESCRIPTION "método para gravar requisição de compras no Protheus";
	WSSYNTAX "/me/v1/request/save"; 
	PATH "/me/v1/request/save" ;
	TTALK 'v1';
	PRODUCES APPLICATION_JSON

	WSMETHOD PUT DESCRIPTION "Método para alterar/excluir requisição de compras no Protheus";
	 WSSYNTAX "/me/v1/request/editOrCancel";
	 PATH "/me/v1/request/editOrCancel"  PRODUCES APPLICATION_JSON

    WSMETHOD GET polist DESCRIPTION  "List of Outstanding Purchase Order" ;
             WSSYNTAX "/me/v1/purchaseorders" ;
             PATH "/me/v1/purchaseorders" ;
             PRODUCES APPLICATION_JSON

	WSMETHOD POST poinsert DESCRIPTION  "Insert of Outstanding Purchase Order" ;
             WSSYNTAX "/me/v1/purchaseorders" ;
             PATH "/me/v1/purchaseorders" ;
			 TTALK 'v1';
             PRODUCES APPLICATION_JSON		 

END WSRESTFUL

WSMETHOD GET polist WSSERVICE MercadoEletronico
Local oPedidos := PedidosDeCompra():New(self)
Local lRet := .F.

	lRet := oPedidos:getPurchaseOrders()
	FreeObj(oPedidos)

Return lRet

WSMETHOD POST poinsert WSSERVICE MercadoEletronico
Local oPedidos := PedidosDeCompra():New(self)
Local lRet := .F.

	lRet := oPedidos:postPurchaseOrder(OPERATION_INSERT)
	FreeObj(oPedidos) 

Return  lRet

//----Payload to create request order
WSMETHOD POST WSSERVICE MercadoEletronico
// Return .T.
// Static Function Save
	Local cJson   := SELF:GetContent()
	// Local cJson   := GetBodyRequest()
	Local oJson   := JSONOBJECT():NEW()
	Local oHeader := Nil
	Local oItems  := Nil
	Local aHeader := {}
	Local aItems  := {}	
	Local _lOk    := .T. as boolean
	Local i		  := 0
	Local cLogSuccess 	:= "" 
	Local cLogError 	:= ""
	Local oResponse   := JsonObject():New()

	Private lMsHelpAuto := .T. 	  // variável que define que o help deve ser gravado no arquivo de log e que as informações estão vindo à partir da rotina automática.
	Private lMsErroAuto := .F. 	  // variável de controle interno da rotina automática que informa se houve erro durante o processamento.
	Private lAutoErrNoFile := .T. // força a gravação das informações de erro em array para manipulação da gravação.	

	::SetContentType(DEF_JSON_CONTENT_TYPE)

	If !(oJson:FromJson(cJson) == Nil)
		SetRestFault(400,"Error: Failure to load method json sent by [Post/purchase]. Check the parameters and try again!")
		Return .F.
	EndIf

	oHeader := oJson['header']
	oItems  := oJson['items']['data']

	//Validações:
	If (oHeader['status'] != Status_Aprovada)
		SetRestFault(400,"Error: Requisição no "+cvaltochar(oHeader['requestId'])+" não está aprovada! Tente novamente.")
		Return .F.
	Else

		setHeader(oHeader, @aHeader, GetSXENum("SC1","C1_NUM"))

		For i := 1 to Len(oItems)
			If (isValid(oItems[i], @cLogSuccess, @cLogError))
				setItems(oItems[i], @aItems)
			EndIf
		Next i

		aReturn := saveRequest(aHeader, aItems)

		If(aReturn[1])
			ConfirmSX8()
			cLogSuccess += aReturn[2]+chr(13)+chr(10)
			oResponse['code'] := 200
			oResponse['message'] := "Request order saved successfully in Protheus!"
			oResponse['status'] := 200
			oResponse['detailedMessage'] := cLogSuccess
			_lOk := .T.
			::SetResponse( oResponse )
		Else
			RollbackSX8()
			cLogError += aReturn[2]+chr(13)+chr(10)
			oResponse['code'] := 1
			oResponse['message'] := "Error: Failure to save request order in Protheus!"
			oResponse['status'] := 500
			oResponse['detailedMessage'] := cLogError
			_lOk := .F.

			SetRestFault( oResponse['code'],;
                        oResponse['message'],;
                        .T.,;
                        oResponse['status'],;
                        oResponse['detailedMessage'])

			// SetRestFault(400,"Error: " + oResponse['detailedMessage'])

		EndIf

	EndIf

	// Limpa memória
	FreeObj(oJson)
	FreeObj(oResponse)
	aSize(aItems,0)
	aItems := Nil
	aSize(aHeader,0)
	aHeader := Nil
	

Return(_lOk)

//----Payload to edit or cancel request order
WSMETHOD PUT WSRECEIVE Null WSSERVICE MercadoEletronico

	Local cJson   := SELF:GetContent()
	Local oJson   := JSONOBJECT():NEW()
	Local oHeader := Nil
	Local oItems  := Nil
	Local aHeader := {}
	Local aItems  := {}	
	Local _lOk    := .T. as boolean
	Local i		  := 0
	Local cLogSuccess 	:= "" 
	Local cLogError 	:= ""	
	
	Private lMsHelpAuto := .T. 	  // variável que define que o help deve ser gravado no arquivo de log e que as informações estão vindo à partir da rotina automática.
	Private lMsErroAuto := .F. 	  // variável de controle interno da rotina automática que informa se houve erro durante o processamento.
	Private lAutoErrNoFile := .T. // força a gravação das informações de erro em array para manipulação da gravação.	

	Self:SetContentType(DEF_JSON_CONTENT_TYPE)

	If !(oJson:FromJson(cJson, @oJson)==Nil)
		SetRestFault(400,"Error: Failure to load method json sent by [Post/purchase]. Check the parameters and try again!")
		Return .F.
	EndIf

	oHeader := oJson['header']
	oItems  := oJson['items']['data']

	//Validações:

	If (oHeader['status'] != Status_Aprovada)
		SetRestFault(400,"Error: Requisição no "+cvaltochar(oHeader['requestId'])+" não está aprovada! Tente novamente.")
		Return .F.
	Else
			
		setHeader(oHeader, @aHeader, getRequestById(oHeader['requestId']))

		If (!oHeader['isCanceled'])

			For i := 1 to Len(oItems)
				If (isValid(oItems[i], @cLogSuccess, @cLogError))
					setItems(oItems[i], @aItems)
				EndIf
			Next i

		EndIf	

		aReturn := saveRequest(aHeader, aItems, iIf(!oHeader['isCanceled'], 4, 5))

		If(aReturn[1])
			cLogSuccess += aReturn[2]+chr(13)+chr(10)
			oResponse['code'] := 200
			oResponse['message'] := "Request order saved successfully in Protheus!"
			oResponse['status'] := 200
			oResponse['detailedMessage'] := cLogSuccess
			_lOk := .T.
			::SetResponse( oResponse )
		Else 
			cLogError += aReturn[2]+chr(13)+chr(10)
			oResponse['code'] := 1
			oResponse['message'] := "Error: Failure to save request order in Protheus!"
			oResponse['status'] := 500
			oResponse['detailedMessage'] := cLogError
			_lOk := .F.

			SetRestFault( oResponse['code'],;
                        oResponse['message'],;
                        .T.,;
                        oResponse['status'],;
                        oResponse['detailedMessage'])

			// SetRestFault(400,"Error: " + oResponse['detailedMessage'])
		EndIf

	EndIf

Return(_lOk)

Static Function setHeader(objH, aHeader, cNum)
	If !Empty(cNum)
		aAdd(aHeader, {"C1_NUM", cNum })
		// aAdd(aHeader, {"C1_UNIDREQ","006"})
		aAdd(aHeader, {"C1_SOLICIT", substr(alltrim(objH['loginName']),1,tamsx3('C1_SOLICIT')[1]) })
		aAdd(aHeader, {"C1_EMISSAO",stod(strTran(left(objH['creationDate'],10),"-","")) })
	EndIf
Return

Static Function setItems(objItem, aItems)
	Local aItem := {}
	aAdd(aItem, {"C1_ITEM"   , strZero(objItem['item'],2), Nil})
	aAdd(aItem, {"C1_PRODUTO", Alltrim(objItem['clientProductId']), Nil})
	aAdd(aItem, {"C1_QUANT"  , objItem['quantity'], Nil})
	aAdd(aItem, {"C1_DATPRF" , dDatabase, Nil})
	aAdd(aItem, {"C1_LOCAL"  , "01"     , Nil})
	aAdd(aItem, {"AUTVLDCONT", "N"      , Nil})
	if SC1->( FieldPos("C1_XIDME")) > 0
	   aAdd(aItem, {"C1_XIDME", cValTochar(objItem['requestId']), Nil})
	endif 
	aAdd(aItems, aItem)

	aSize(aItem,0)
	aItem := Nil

Return

Static Function isValid(item, cLogSuccess, cLogError)
	Local lRet := .T.
	DbSelectArea("SB1")
	SB1->(DbSetOrder(1))
	If (!SB1->(DbSeek(xFilial("SB1")+Alltrim(item['clientProductId']))))
		lRet :=.F.
		cLogError += "Erro: Produto "+Alltrim(item['clientProductId'])+" não localizado no Protheus!"
	EndIf
Return(lRet)


Static Function getRequestById(requestId)
	Local cNum := cvaltochar(requestId)
	Local cTemp := getNextAlias()

        beginSql alias cTemp
            select SC1.C1_NUM AS IDREQ
            from %table:SC1% SC1
            where C1_FILIAL = %xFilial:SC1%
            and C1_XIDME = %exp:cNum%
            and SC1.%notdel%
        endSql

        If !(cTemp)->(eof())
			cNum := (cTemp)->IDREQ
		Else
			cNum := ""
        EndIf
        (cTemp)->( dbCloseArea() )

Return(cNum)

Static Function saveRequest(aHeader, aItems, nOpc)
	Local aRet 	:= {.T., ""}
	Local aErr 	:= {}
	Local i 	:= 0	
	Default 	:= 3
    Private lMsHelpAuto  := .T.
	Private lMsErroAuto  := .F.    

	If (len(aHeader)>0)
		
		lMsErroAuto := .F.
		MsExecAuto({|x,y| Mata110(x,y, nOpc)}, aHeader, aItems)

		If !lMsErroAuto
			aRet[1] := .T.
			aRet[2] := SC1->C1_NUM
		Else
			aErr := GetAutoGrLog()
			For i := 1 to len(aErr)
				aRet[2] += aErr[i]
			Next i
			aRet[1] := .F.
		EndIf
		
	Else
		aRet := {.F., ""}
	EndIf

Return (aRet)


// User Function API_REQUEST(lJob)

// 	Local baseUrl    := Alltrim(SuperGetMV("MV_XURLME",,'https://stg.api.mercadoe.com'))
// 	Local version 	 := "v1"
// 	Local methodName := "requests"
// 	Local _type 	 := "GET"
// 	Local oApiMe   	 := MeServices():New(cEmpAnt, cFilAnt, baseUrl, version, methodName, _type)
// 	Local oRequest 	 := oApiMe:getJson()
// 	Local oItems   	 := Nil
// 	//Local meID 		 := Iif(empty(SC1->C1_PROGRAM), oProduct:getId("CLIENTPRODUCTID", alltrim(M->B1_COD), "PRODUCTID"),alltrim(SC1->C1_PROGRAM))
// 	Local aReturn 	 := array(2)
// 	Local i			 := 0
// 	Local j			 := 0
// 	Local aHeader	 := {}
// 	Local aItems	 := {}
// 	Local cLogSuccess:= ""
// 	Local cLogError  := ""
// 	Private lMsHelpAuto := .T. 	  // variável que define que o help deve ser gravado no arquivo de log e que as informações estão vindo à partir da rotina automática.
// 	Private lMsErroAuto := .F. 	  // variável de controle interno da rotina automática que informa se houve erro durante o processamento.
// 	Private lAutoErrNoFile := .T. // força a gravação das informações de erro em array para manipulação da gravação.

// 	Default lJob 	 := .F.

// 	If ( Len(oRequest)> 0 )

// 		For i := 1 to Len(oRequest)

// 			freeObj(oApiMe)

// 			If oRequest[i]:status != Status_Aprovada
// 				loop 
// 			EndIf

// 			oApiMe := MeServices():New(cEmpAnt, cFilAnt, baseUrl, version, methodName + "/" + cValTochar(oRequest[i]:RequestId) + "/Items", _type)
// 			oItems := oApiMe:getJson()

// 			setHeader(oRequest[i], @aHeader)

// 			For j := 1 to Len(oItems)
// 				If (isValid(oItems[j], @cLogSuccess, @cLogError))
// 					setItems(oItems[j], @aItems)
// 				EndIf
// 			Next j

// 			aReturn := saveRequest(aHeader, aItems)

// 			If(aReturn[1])
// 				cLogSuccess += aReturn[2]+chr(13)+chr(10)
// 			Else 
// 				cLogError += aReturn[2]+chr(13)+chr(10)
// 			EndIf
			
// 			aHeader	 := {}
// 			aItems	 := {}

// 		Next i

// 		AutoGrLog("Resultado final...")
// 		AutoGrLog("Sucesso:")
// 		AutoGrLog(cLogSuccess)
// 		AutoGrLog("Erro:")
// 		AutoGrLog(cLogError)
// 		MostraErro()

// 	EndIf
	
// 	// aReturn := oApiMe:send(meID)

// 	// If(aReturn[1])

// 	// 	If(meId == "0")
// 	// 		oRequest:type := "GET"
// 	// 		meId := oRequest:getId("CLIENTPRODUCTID", alltrim(M->B1_COD), "PRODUCTID")
// 	// 	EndIf

// 	// 	oApiMe:saveIdToProtheus("SC1", /*"C1_XIDME"*/ "C1_PRD", SC1->(recno()), meId)
// 	// 	MsgInfo(msg_success,"Atenção!")

// 	// Else
// 	// 	MsgStop(msg_error, "Atenção!")
// 	// EndIf

// 	// conout("resultado da chamada a api supplier ->" + alltochar(aReturn[1]) + "-->" + alltochar(aReturn[2]) )

// Return


User Function TstSaveMe

RpcSetEnv("00")
Save()

Return

Static Function GetBodyRequest
Local cBody := ""

cBody := '{' + ;
    '"header": {' + ;
        '"note": "",' + ;
        '"isCanceled": false,' + ;
        '"integrationTag": "BLUEFIT_RASSUNCAO",' + ;
        '"creationDate": "2025-08-28T09:59:06.83Z",' + ;
        '"title": "Teste ipaas 2808X003",' + ;
        '"clientDeliveryPlaceId": "01",' + ;
        '"requestId": 38688510,' + ;
        '"loginName": "BLUEFIT_RASSUNCAO",' + ;
        '"name": "Renata Assunção",' + ;
        '"currency": "",' + ;
        '"category": "Normal",' + ;
        '"brokerIntegrationTag": "000017",' + ;
        '"email": "renata.assuncao@bluefitacademia.com.br",' + ;
        '"status": 124' + ;
    '},' + ;
    '"items": {' + ;
        '"hits": 1,' + ;
        '"data": [' + ;
            '{' + ;
                '"requestId": 38688510,' + ;
                '"item": 1,' + ;
                '"isCanceled": false,' + ;
                '"isChange": false,' + ;
                '"isGeneric": false,' + ;
                '"isService": false,' + ;
                '"quantity": 1,' + ;
                '"description": "TESTE ME",' + ;
                '"complement": "",' + ;
                '"note": "",' + ;
                '"measurementUnit": "UN",' + ;
                '"clientReferenceProductId": "000000000000139",' + ;
                '"clientProductId": "000000000000139",' + ;
                '"clientGroupId": "0010",' + ;
                '"estimatedPrice": 1,' + ;
                '"currency": "",' + ;
                '"materialApplication": "0",' + ;
                '"materialCategory": "",' + ;
                '"status": 0,' + ;
                '"deliveryDate": "2025-09-05T00:00:00Z",' + ;
                '"productId": 115128756,' + ;
                '"deliveries": [],' + ;
                '"subItems": []' + ;
            '}' + ;
        ']' + ;
    '},' + ;
    '"borgs": {' + ;
        '"hits": 2,' + ;
        '"data": [' + ;
            '{' + ;
                '"code": "01",' + ;
                '"description": "Bluefit Empresa 01",' + ;
                '"virtualEntityField": "EMPRESA",' + ;
                '"virtualEntityDescription": "Empresa"' + ;
            '},' + ;
            '{' + ;
                '"code": "010101",' + ;
                '"description": "Bluefit Filial 010101",' + ;
                '"virtualEntityField": "FILIAL",' + ;
                '"virtualEntityDescription": "Filial"' + ;
            '}' + ;
        ']' + ;
    '}' + ;
'}'

Return cBody

User Function TstPC

Local aDados := {}
Local aItems := {}
Local aItem := {}

// ...continue com o restante da função...
RpcSetEnv("01")

// Preenchendo aDados conforme exemplo
aAdd(aDados, {"C7_FILIAL", xFilial("SC7"), Nil})
aAdd(aDados, {"C7_NUM", "A27746", Nil})
aAdd(aDados, {"C7_FORNECE", "000001", Nil})
aAdd(aDados, {"C7_LOJA", "01", Nil})
aAdd(aDados, {"C7_DATPRF", stod("20250630"), Nil})
aAdd(aDados, {"C7_EMISSAO", stod("20250630"), Nil})
aAdd(aDados, {"C7_NUMSC", "", Nil})
aAdd(aDados, {"C7_COND", "001", Nil})
AADD(aDados, {"C7_CONTATO" 	,""				,Nil}) //Obrigatório
AADD(aDados, {"C7_FILENT" 	,xFilial("SC7")			,Nil}) //Obrigatório

// Preenchendo aItems conforme exemplo

aAdd(aItem, {"C7_ITEM", "0001", Nil})
aAdd(aItem, {"C7_PRODUTO", "000000000000001", Nil})
aAdd(aItem, {"C7_LOCAL", "01", Nil})
aAdd(aItem, {"C7_QUANT", 1.0000, Nil})
aAdd(aItem, {"C7_UM", "UN", Nil})
aAdd(aItem, {"C7_PRECO", 50000.0000, Nil})
aAdd(aItem, {"C7_TOTAL", 50000.0000, Nil})
aAdd(aItem, {"C7_QUJE", 0.0000, Nil})
aAdd(aItem, {"C7_RESIDUO", "", Nil})
aAdd(aItem, {"C7_DESCRI", "G7S13 V2 SUPINO VERTICAL CONVERGENTE MATRIX PF/PR ", Nil})
aAdd(aItem, {"C7_TXMOEDA", 0.0000, Nil})
aAdd(aItem, {"C7_MOEDA", 1.0000, Nil})
aAdd(aItem, {"C7_IPI", 0.0000, Nil})

aAdd(aItems, aItem)

lMsErroAuto := .F.


MsExecAuto( { | a, b, c, d, e | MATA120( a, b, c, d, e ) }, 1, aDados, aItems, 3)
// ...existing code...

If lMsErroAuto
    cErro := MostraErro()
	VarInfo("EXECAUTO_ERRO =>", cErro)
EndIf

return nIL
