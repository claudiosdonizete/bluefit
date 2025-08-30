//---- Libraries
#INCLUDE "TOTVS.CH"
#INCLUDE "PROTHEUS.CH"
#INCLUDE "RESTFUL.CH"
#Include 'FWMVCDEF.ch'
#INCLUDE "TOPCONN.CH"
#INCLUDE "TBICONN.CH"

#define FIELD_JSONDISPLAY       1
#define FIELD_NAMEQUERY         2
#define FIELD_JSONFIELDDISPLAY  3
#define FIELD_JSONFIXED         4
#define FIELD_STRUCT            5

#define FIELD_NAME              1   
#define FIELD_TYPE              2            

#define FIELD_CONTENT           2   

#define OPERATION_INSERT        3   
#define OPERATION_REVERT        5   

#define INBOUND_POSITION        1

#define POSITION_PRODUCTCODE    1
#define POSITION_WAREHOUSE      2
#define POSITION_PRODUCTLOT     4

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
Return getPurchaseOrders(self)

WSMETHOD POST poinsert WSSERVICE MercadoEletronico
Return postPurchaseOrder(self, OPERATION_INSERT)

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

Static Function postPurchaseOrder(oWs,nOperation)
    Local oDataBase as object
    Local aAreaAnt := GetArea()
    Local aDados   := {}
    Local aItems   := {}
    Local aItem    := {}
    Local nSaveSx8Len := GetSx8Len()
    Local nLen
    Local aFields  := {}
    Local aFieldsItems := {}
    Local lRet := .T.
    Local cCatch
    Local nX, nI, nF
    Local aBody    := {}
    Local oBody
    Local xValue
    Local cErroBlk    := ''
    Local oException  := ErrorBlock({|e| cErroBlk += e:Description + e:ErrorStack, lRet := .F. })
    Local oResponse   := JsonObject():New()
    Local aOrdem      := {}
    Local aDocItems   := {}
    Local aBodyItem   := {}
    Local cChave      := ""
    Local nAscan
    Local cCampo
    Local cAtributo
    Local cBranchId     := ""
    Local cDocumentId   := ""

    Private lMSErroAuto := .F.
    Private lMSHelpAuto := .T.

    Begin Sequence

        oBody := JsonObject():New()
        cCatch := oBody:FromJSON( oWS:GetContent() ) 

        If cCatch == Nil 

            oDataBase := PurchaseOrderAdapter():new('GET')
            aFields      := aClone(oDataBase:GetFields())
            aFieldsItems := aClone(oDataBase:getFItems())

            //-------------------------------
            // Adiciona os dados em um vetor
            //-------------------------------
            aBody       := oBody:GetNames()
            nLen        := Len(aFields)
            nLenFItens  := Len(aFieldsItems)
			Conout("---------------------------------------------------------")
            VarInfo("aBody =>", aBody)
            Conout("---------------------------------------------------------")
            Conout("---------------------------------------------------------")
            VarInfo("oBody =>", oBody)
            Conout("---------------------------------------------------------")
            Conout("---------------------------------------------------------")
            VarInfo("aFields =>", aFields)
            Conout("---------------------------------------------------------")
			Conout("---------------------------------------------------------")
            VarInfo("nLen => ", nLen)
            Conout("---------------------------------------------------------")

            // Se não for inclusão
            If nOperation <> OPERATION_INSERT
                SC7->(DbSetOrder(1))
                aOrdem := Separa(SC7->(IndexKey(1)),"+")
            EndIf

            For nX := 1 To nLen
                cAtributo := aFields[nX,FIELD_JSONDISPLAY]
				Conout("---------------------------------------------------------")
				VarInfo("cAtributo => ", cAtributo)
				Conout("---------------------------------------------------------")
                // Se for inclusao, ou se encontrar o campo na chave de indice e não for o campo documentitems
                If (Alltrim(lower(cAtributo))<>"purchaseorderitems" ) //.And. Ascan(aOrdem, {|e| e == aFields[nX,FIELD_STRUCT,FIELD_NAME]}) > 0 )
                    // Se encontrar o campo do body na lista de campos esperados
                    If Ascan(aBody, { |e| Alltrim(Upper(e)) == Alltrim(Upper(cAtributo))} ) > 0
                    
                        xValue := ""
                        cCampo := aFields[nX,FIELD_STRUCT,FIELD_NAME]
                        // Se conseguir obter o valor do json
                        If oBody:GetJsonValue(lower(cAtributo), @xValue )
						 	If Left(cCampo,3)=="C7_"
                        
								// Faz as conversões ou completa com espaços
								If FwGetSx3Cache(cCampo,"X3_TIPO") == "D"
									xValue := STOD(xValue)
								ElseIf FwGetSx3Cache(cCampo,"X3_TIPO") == "C" 
									xValue := PAD(xValue,FwGetSx3Cache(cCampo,"X3_TAMANHO"))
								Endif

								If cCampo == "C7_FILIAL"
									xValue := xFilial("SC7")
									cBranchId := xValue
								ElseIf cCampo == "C7_NUM"
									xValue := CriaVar("C7_NUM", .T.)
									cDocumentId := xValue
								EndIf

								aAdd(aDados, {cCampo, xValue      ,Nil})

							EndIf
                        Else
                            Conout("---------------------------------------------------------")
                            VarInfo("ACHOU_MAS_NAO_LEU_JSONVALUE", cAtributo)
                            Conout("---------------------------------------------------------") 
                        EndIf

                    Else
                        If lower(alltrim(cAtributo))$"branchid#purchaseordernumber#issuedate"
                            If lower(alltrim(cAtributo)) == "branchid"
                                cBranchId := xFilial("SC7")
                                cCampo    := "C7_FILIAL"
                                xValue    := cBranchId  
                            ElseIf lower(alltrim(cAtributo)) == "purchaseordernumber"
                                cDocumentId := CriaVar("C7_NUM", .T.)
                                cCampo    := "C7_NUM"
                                xValue    := cDocumentId
                            ElseIf lower(alltrim(cAtributo)) == "issuedate"
                                xValue := dDataBase
                                cCampo := "C7_EMISSAO"
                            EndIf
                            aAdd(aDados, {cCampo, xValue      ,Nil})
                        EndIf
                        Conout("---------------------------------------------------------")
                        VarInfo("NAO_ACHOU => ", Alltrim(Upper(cAtributo)))
                        Conout("---------------------------------------------------------") 
                    EndIf
                ElseIf  nOperation == OPERATION_INSERT .And. ;
                        Alltrim(lower(cAtributo)) == "purchaseorderitems"
                    
                    aDocItems := {}
                    oBody:GetJsonValue(lower(cAtributo), @aDocItems )
                    nLenItems := Len(aDocItems)
                    Conout("---------------------------------------------------------")
                    VarInfo("aDocItems => ", aDocItems)
                    Conout("---------------------------------------------------------")
                    aItems := {}
                    
                    // Percorre os itens a transferir
                    For nI := 1 To nLenItems

                        aBodyItem := aDocItems[nI]:GetNames()
                        Conout("---------------------------------------------------------")
                        VarInfo("aBodyItem => ", aBodyItem)
                        Conout("---------------------------------------------------------")
                        aItem := {}

                        // Verifica se os campos necessarios para incluir um item, foram enviados no Body do Item
                        For nF := 1 To nLenFItens
                            cAtributo := aFieldsItems[nF,FIELD_JSONDISPLAY]
                            If Ascan(aBodyItem, { |e| Alltrim(Upper(e)) == Alltrim(Upper(cAtributo))} ) > 0
                                xValue := ""
                                cCampo := aFieldsItems[nF,FIELD_STRUCT,FIELD_NAME]
                                // Se conseguir obter o valor do json
                                If aDocItems[nI]:GetJsonValue(lower(cAtributo), @xValue ) 
									If Left(cCampo,3)=="C7_"
										// Faz as conversões ou completa com espaços
										If FwGetSx3Cache(cCampo,"X3_TIPO") == "D"
											xValue := STOD(xValue)
										ElseIf FwGetSx3Cache(cCampo,"X3_TIPO") == "C" 
											xValue := PAD(xValue,FwGetSx3Cache(cCampo,"X3_TAMANHO"))
										Endif

										If .t. // PreValid(lower(cAtributo),xValue,oResponse,cAtributo,nI)
											aAdd(aItem, {cCampo, xValue, Nil})
										Else
											lRet := .F.
											Break 
										Endif
										
										Conout("---------------------------------------------------------")
										VarInfo("achou Achou o atributo => ", Alltrim(Upper(cAtributo)))
										Conout("---------------------------------------------------------")

										Conout("---------------------------------------------------------")
										VarInfo("xValue => ", xValue)
										Conout("---------------------------------------------------------")
									EndIf
                                Else
                                    Conout("---------------------------------------------------------")
                                    VarInfo("ACHOU_MAS_NAO_LEU_JSONVALUE => ", cAtributo)
                                    Conout("---------------------------------------------------------") 
                                EndIf
                            Else
                                Conout("---------------------------------------------------------")
                                VarInfo("Não achou Achou o atributo => ", Alltrim(Upper(cAtributo)))
                                Conout("---------------------------------------------------------")
                            EndIf

                        Next

                        Aadd(aItems, aItem)
                        If .T. // TriagemItem(aItem,oResponse,nI)
                            // aItems[Len(aItems)] := aClone(aItem)
                        Else
                            lRet := .F.
                            Break 
                        EndIf
                    Next

                EndIf
            Next

            Conout("---------------------------------------------------------")
            VarInfo("aDados", aDados)
            Conout("---------------------------------------------------------")


            Conout("---------------------------------------------------------")
            VarInfo("aItems =>", aItems)
            Conout("---------------------------------------------------------")

            Conout("---------------------------------------------------------")
            VarInfo("nOperation", nOperation)
            Conout("---------------------------------------------------------")   

            //-----------------------------
            // Executa a rotina automatica
            //-----------------------------
            Begin Transaction
                // Se não for inclusão, monta a chave conforme a ordem da tabela
                If nOperation <> OPERATION_INSERT

                    Conout("---------------------------------------------------------")
                    VarInfo("aOrdem", aOrdem)
                    Conout("---------------------------------------------------------")

                    nLen := Len(aOrdem)-1
                    For nX := 1 To nLen
                        nAscan := Ascan(aDados, {|e| e[1] == aOrdem[nX]})
                        If nAscan > 0
                            cChave += aDados[nAscan,2]
                        Else
                            // Caso algum dos campos chaves não foi enviado no body, rejeita a request
                            lRet := .F.
                            oResponse['code'] := 2 
                            oResponse['status'] := 400
                            oResponse['message'] := If(nOperation==OPERATION_REVERT,"REVERT","")+" failed"
                            cChave := aOrdem[nX]
                            nAscan := Ascan(aFields, {|e| e[FIELD_STRUCT,FIELD_NAME] == cChave})
                            If nAscan > 0
                                cChave := aFields[nAscan,FIELD_JSONDISPLAY]
                            EndIf
                            oResponse['detailedMessage'] := "key not found on body -> " + lower(cChave)
                            Break 
                        EndIf
                    Next
                    Conout("---------------------------------------------------------")
                    VarInfo("cChave", cChave)
                    Conout("---------------------------------------------------------")
                    If ! SC7->(DbSeek(cChave))
                        lRet := .F.
                        oResponse['code'] := 3 
                        oResponse['status'] := 400
                        oResponse['message'] := If(nOperation==OPERATION_REVERT,"REVERT","")+" failed"
                        oResponse['detailedMessage'] := "Record not found, key -> " + cChave
                        Break
                    EndIf
                    Conout("---------------------------------------------------------")
                    VarInfo("SC7->C7_NUM", SC7->C7_NUM)
                    Conout("---------------------------------------------------------")
                Else
                    // aDados := PrepDados(aDados,aItems) 
                EndIf
         
				MsExecAuto( { | a, b, c, d, e | MATA120( a, b, c, d, e ) }, 1, aDados, aItems,  nOperation)
                
                If lMsErroAuto
                    lRet := .F.
                    DisarmTransaction()
                    cErro := MostraErro("\errolog\")
                    While GetSx8Len() > nSaveSx8Len
                        RollBackSX8()
                    End
                    Conout("---------------------------------------------------------")
                    VarInfo("EXECAUTO_ERRO", cErro)
                    Conout("---------------------------------------------------------")
                    oResponse['code'] := 4 
                    oResponse['status'] := 400
                    oResponse['message'] := If(nOperation==OPERATION_INSERT,"INSERT",If(nOperation==OPERATION_REVERT,"REVERT",""))+" failed"
                    oResponse['detailedMessage'] := EncodeUtf8(cErro)
                Else
					// cDocumentId := SC7->C7_NUM
                    Conout("---------------------------------------------------------")
                    VarInfo("EXECAUTO_SUCESSO", "")
                    Conout("---------------------------------------------------------") 

                    If (nOperation==OPERATION_INSERT)
                        cFilterString := 'branchid='+cBranchId+'&purchaseordernumber='+Alltrim(cDocumentId)
                   
                        While (GetSx8Len() > nSaveSx8Len)
                            ConfirmSX8()
                        End

                        aQueryString := StrFilter(cFilterString)

                        oDataBase:setUrlFilter(aQueryString)

                        Conout("---------------------------------------------------------")
                        VarInfo("cFilterString", cFilterString)
                        Conout("---------------------------------------------------------") 

                        Conout("---------------------------------------------------------")
                        VarInfo("aQueryString", aQueryString)
                        Conout("---------------------------------------------------------") 

                        oDataBase:getListPurchaseOrders()

                        If oDataBase:lOk
                            Conout("---------------------------------------------------------")
                            VarInfo("oDataBase:lOk => ", oDataBase:lOk)
                            Conout("---------------------------------------------------------") 
                            oWS:SetResponse(oDataBase:getJSONResponse())
                            lRet := .T.
                        Else
                            oResponse['code'] := 5 // oDataBase:GetCode()
                            oResponse['status'] := 400
                            oResponse['message'] := 'It was not possible to filter the records!'
                            oResponse['detailedMessage'] := oDataBase:GetMessage()
                            lRet := .F.
                            Break
                        EndIf
                    Else
                        oResponse['code'] := 1 // oDataBase:GetCode()
                        oResponse['status'] := 200
                        oResponse['message'] := "reversed  successfully"
                        oResponse['detailedMessage'] := "Document reversal operation was performed successfully"
                        SetResponse(oResponse:ToJson())
                    EndIf
                    If nOperation <> OPERATION_INSERT
                         oWs:SetStatus(200)
                    EndIf
                EndIf
            End Transaction
        Else
            oResponse['code'] := 6 
            oResponse['status'] := 400
            oResponse['message'] := "Invalid json body"
            oResponse['detailedMessage'] := oWS:GetContent()
            lRet := .F.
        Endif

		// RECOVER
		// 	oResponse['code'] := 1
		// 	oResponse['status'] := 500
		// 	oResponse['message'] := 'Aconteceu um erro inesperado no serviço!'
		// 	oResponse['detailedMessage'] := cErroBlk

		// 	SetRestFault( oResponse['code'],;
		// 				  oResponse['message'],;
		// 			  	  .T.,;
		// 				  oResponse['status'],;
		// 				  oResponse['detailedMessage'] )
    End Sequence

    ErrorBlock(oException)

    If !lRet

		// Ver com Roberto, pq não funcionou Essa sintaxe
        SetRestFault(  oResponse['code'],;
                       oResponse['message'],;
                       .T.,;
                       oResponse['status'],;
                       oResponse['detailedMessage'] )
		
		// SetRestFault(oResponse['status'],"Error: " + oResponse['detailedMessage'])

    EndIf

    RestArea(aAreaAnt)
    FreeObj(oDataBase)
    FreeObj(oResponse)
    FreeObj(oBody)
    aSize(aAreaAnt,0)
    aSize(aDados,0)
    aSize(aFields,0)
    aSize(aFieldsItems,0)
    aSize(aBody,0)
    aSize(aOrdem,0)
    aSize(aDocItems,0)
    aSize(aBodyItem,0)
    aSize(aItems,0)
    aSize(aItem,0)

Return lRet

/*/{Protheus.doc} getPurchaseOrders
Retorna lista de pedido de compra em aberto
@type function
@version 1.0
@author Claudio Donizete
@since 29/08/2025
@param oWS, object, Objeto web
@return logical, indica se foi ou nao processado corretamente
/*/
Static Function getPurchaseOrders(oWS)
    Local lRet         As logical 
    Local oDataBase    As object
    Local oBody        As Object
    Local nPage       
    Local nPageSize   
    Local cOrder      
    Local cFields     
    Local aQueryString := {}
    Local cErroBlk     := ''
    Local oException   := ErrorBlock({|e| cErroBlk := e:Description + e:ErrorStack, lRet := .F. })
    Local oResponse    := JsonObject():New()
    Local cJSONResp    := ""
    
    lRet := .T.

    Begin Sequence

        oBody := JsonObject():New()
        cCatch := oBody:FromJSON( oWS:GetContent() ) 

        If cCatch == Nil 
            oWS:Page        := If(oBody:HasProperty('page'), oBody['page'], 1)
            oWS:PageSize    := If(oBody:HasProperty('pageSize'), oBody['pageSize'], 10)

            If oBody:HasProperty('fields')
                oWS:Fields := oBody["fields"]
            EndIf

            If oBody:HasProperty('filterString')
                oWS:aQueryString := StrFilter(oBody['filterString'])
            Endif
        EndIf

        If Empty(oWS:Page)
            oWS:Page := 1
        EndIf

        If Empty(oWS:PageSize)
            oWS:PageSize := 10
        EndIf

        nPage        := oWS:Page
        nPageSize    := oWS:PageSize
        cOrder       := oWS:Order
        cFields      := oWS:Fields
        aQueryString := oWS:aQueryString

        oDataBase := PurchaseOrderAdapter():new( 'GET' ) 
        oDataBase:setPage( nPage )
        oDataBase:setPageSize( nPageSize )
        oDataBase:SetOrderQuery( cOrder )
        oDataBase:SetFields( cFields )  
        oDataBase:setUrlFilter( aQueryString )
        oDataBase:getListPurchaseOrders()
  
    End Sequence

    ErrorBlock(oException)
  
    If lRet
        //-- Verifica execucao da query
        If oDataBase:lOk
            cJSONResp := oDataBase:getJSONResponse()
            oWS:SetResponse(cJSONResp)
            oWs:SetStatus(200)
        Else
            oResponse['code'] := oDataBase:GetCode()
            oResponse['status'] := 400
            oResponse['message'] := 'Error'
            oResponse['detailedMessage'] := 'It was not possible to filter the records! ' + oDataBase:GetMessage()
            lRet := .F.
        EndIf
    Else
        oResponse['code'] := 133
        oResponse['status'] := 500
        oResponse['message'] := 'Error' // Aconteceu um erro inesperado no servico!
        oResponse['detailedMessage'] := 'An unexpected error occurred in the service! ' + cErroBlk
    EndIf

    If !lRet
        SetRestFault( oResponse['code'],;
                        oResponse['message'],;
                        .T.,;
                        oResponse['status'],;
                        oResponse['detailedMessage'])
    EndIf
  
    oDataBase:DeActivate()
    FreeObj(oDataBase)
    FreeObj(oResponse)  
    
Return lRet

/*/{Protheus.doc} StrFilter
Trata Filtro em body das apis
@type function
@version 1.0  
@author Claudio Donizete
@since 29/08/2025
@param cFilterString, character, Filtro para tradução
@return array, Array com os filtros
/*/
Static Function StrFilter(cFilterString)
Local aRet := {}
Local nLen
Local nX
Local lComplex := "FILTER"$Upper(cFilterString)
Local cAux
Local aAux

// filtros simples
// a requição com: ?propriedade1=valor1&propriedade2=valor2
// exigiria o array como
// aUrlFilter := { ;
//   {"propriedade1", "valor1"},;
//   {"propriedade2", "valor2"} ;
// }
// self:SetUrlFilter(aUrlFilter)
 
// // filtro complexos
// // ?filter=propriedade1 eq 'valor1' and propriedade2 eq 'valor2'
// aUrlFilter := { ;
//   {"FILTER", "propriedade1 eq 'valor1' and propriedade2 eq 'valor2'"};
// }
If lComplex
    // Separa a palavra filter do resto a string de filtro. A palavra FILTER precisa ser em maiusculo.
    cAux := Alltrim(Substr(cFilterString,1,At("=",cFilterString)-1))
    cFilterString := upper(cAux) + "||" + SubStr(cFilterString,At("=",cFilterString)+1)
    aAux := Separa(Strtran(cFilterString,"FILTER=","FILTER||"), "||")
Else
    aAux := Separa(Strtran(cFilterString,"&","="), "=")
EndIf
Aadd(aRet, {})

nLen := Len(aAux)
For nX := 1 To nLen
    If Upper(Alltrim(aAux[nX]))=="FILTER"
        Aadd(aRet[1], aAux[nX])
    Else
        Aadd(aRet[Len(aRet)], aAux[nX])
        // Filtro simples, precisa adicionar uma nova linha no array de retorno
        If nX%2 == 0 .And. nX < nLen
            Aadd(aRet, {})
        Endif
    Endif
Next

aSize(aAux,0)

Conout("---------------------------------------------------------")
VarInfo("aRet", aRet)
Conout("---------------------------------------------------------")

Return aRet



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
