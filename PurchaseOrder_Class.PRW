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

Class PedidosDeCompra FROM LongClassName
    Data oWs

    Method New(oWS)
    Method getPurchaseOrders()
    Method postPurchaseOrder(nOperation)
    Method StrFilter(cFilterString)
    Method ExistPurchaseOrder(cPurchaseOrderId)
    Method GetRequestById(requestId)
    Method PreValid(aDados,aItems,oResponse,nOperation)
    Method GetIdMePurchaseOrder(aDados)
    Method Destroy()

EndClass

Method New(oWS) Class PedidosDeCompra
    ::oWS := oWS
Return Self

Method Destroy() Class PedidosDeCompra
    FreeObj(::oWS)
Return Nil

/*/{Protheus.doc} getPurchaseOrders
Retorna lista de pedido de compra em aberto
@type function
@version 1.0
@author Claudio Donizete
@since 31/08/2025
@param oWS, object, Objeto web
@return logical, indica se foi ou nao processado corretamente
/*/
Method getPurchaseOrders() Class PedidosDeCompra
    Local lRet         As logical 
    Local oDataBase    As object
    Local oBody        As Object
    Local nPage       
    Local nPageSize   
    Local cOrder      
    Local cFields     
    Local aQueryString := {}
    Local cErroBlk     := ''
    Local oException   := ErrorBlock({|e| cErroBlk += e:Description + e:ErrorStack, lRet := .F. })
    Local oResponse    := JsonObject():New()
    Local cJSONResp    := ""
    
    lRet := .T.

    Begin Sequence

        oBody := JsonObject():New()
        cCatch := oBody:FromJSON( ::oWS:GetContent() ) 

        If cCatch == Nil 
            ::oWs:Page        := If(oBody:HasProperty('page'), oBody['page'], 1)
            ::oWs:PageSize    := If(oBody:HasProperty('pageSize'), oBody['pageSize'], 10)

            If oBody:HasProperty('fields')
                ::oWs:Fields := oBody["fields"]
            EndIf

            If oBody:HasProperty('filterString')
                ::oWs:aQueryString := ::StrFilter(oBody['filterString'])
            Endif
        EndIf

        If Empty(::oWs:Page)
            ::oWs:Page := 1
        EndIf

        If Empty(::oWs:PageSize)
            ::oWs:PageSize := 10
        EndIf

        nPage        := ::oWs:Page
        nPageSize    := ::oWs:PageSize
        cOrder       := ::oWs:Order
        cFields      := ::oWs:Fields
        aQueryString := ::oWs:aQueryString

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
            ::oWs:SetResponse(cJSONResp)
            ::oWs:SetStatus(200)
        Else
            oResponse['code'] := oDataBase:GetCode()
            oResponse['status'] := 400
            oResponse['message'] := 'Error'
            oResponse['detailedMessage'] := 'It was not possible to filter the records! ' + oDataBase:GetMessage()
            lRet := .F.
        EndIf
    Else
        VarInfo("cErroBlk =>", cErroBlk)
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
/*/{Protheus.doc} postPurchaseOrder
Retorna lista de pedido de compra em aberto
@type function
@version 1.0
@author Claudio Donizete
@since 31/08/2025
@param ::oWs, object, Objeto web
@return logical, indica se foi ou nao processado corretamente
/*/
Method postPurchaseOrder(nOperation) Class PedidosDeCompra
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
    Local oException  := ErrorBlock({|e| cErroBlk += e:Description + e:ErrorStack, lRet := .F., Break(e) })
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
        cCatch := oBody:FromJSON( ::oWs:GetContent() ) 

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
                                        // Obtem o número da solciitação através do RequestId
										If lower(cAtributo) == "purchaserequestid"
                                            xValue := ::getRequestById(xValue)
                                        Else
                                            // Faz as conversões ou completa com espaços
                                            If FwGetSx3Cache(cCampo,"X3_TIPO") == "D"
                                                xValue := STOD(xValue)
                                            ElseIf FwGetSx3Cache(cCampo,"X3_TIPO") == "C" 
                                                xValue := PAD(xValue,FwGetSx3Cache(cCampo,"X3_TAMANHO"))
                                            Endif
                                        EndIf

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
                    lRet := ::PreValid(aDados,aItems,@oResponse,nOperation)
                    If !lRet
                        Break
                    EndIf
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
                    
                    If nOperation == OPERATION_INSERT
                        If SC7->(FieldPos("C7_XIDME")) > 0 
                            RecLock("SC7", .F.)
                                SC7->C7_XIDME := ::GetIdMePurchaseOrder(aDados)
                            SC7->(MsUnLock())
                        EndIf
                    EndIf

                    If (nOperation==OPERATION_INSERT)
                        cFilterString := 'branchid='+cBranchId+'&purchaseordernumber='+Alltrim(cDocumentId)
                   
                        While (GetSx8Len() > nSaveSx8Len)
                            ConfirmSX8()
                        End

                        aQueryString := ::StrFilter(cFilterString)

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
                            ::oWs:SetResponse(oDataBase:getJSONResponse())
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
                         ::oWs:SetStatus(200)
                    EndIf
                EndIf
            End Transaction
        Else
            oResponse['code'] := 6 
            oResponse['status'] := 400
            oResponse['message'] := "Invalid json body"
            oResponse['detailedMessage'] := ::oWs:GetContent()
            lRet := .F.
        Endif

		RECOVER USING oException
			oResponse['code'] := 1
			oResponse['status'] := 500
			oResponse['message'] := 'Aconteceu um erro inesperado no serviço!'
			oResponse['detailedMessage'] := cErroBlk

			SetRestFault( oResponse['code'],;
						  oResponse['message'],;
					  	  .T.,;
						  oResponse['status'],;
						  oResponse['detailedMessage'] )
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
/*/{Protheus.doc} StrFilter
Trata Filtro em body das apis
@type function
@version 1.0  
@author Claudio Donizete
@since 31/08/2025
@param cFilterString, character, Filtro para tradução
@return array, Array com os filtros
/*/
Method StrFilter(cFilterString) Class PedidosDeCompra
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

/*/{Protheus.doc} ExistPurchaseOrder
Verifica se ja existe um pedido de compra para o ID informado
@type function
@version 1.0  
@author Claudio Donizete
@since       03/09/2025
@param cPurchaseOrderId, character, IDME do pedido de compra
@return logical, .T. se existir, .F. caso contrario
*/
Method ExistPurchaseOrder(cPurchaseOrderId) Class PedidosDeCompra
Local cTemp := getNextAlias()
Local lRet  := .F.

        VarInfo("Antes da Query", cPurchaseOrderId)
        cPurchaseOrderId := cvaltochar(cPurchaseOrderId)

        BeginSql Alias cTemp
            SELECT SC7.C7_NUM
            FROM %table:SC7% SC7
            WHERE C7_FILIAL = %xFilial:SC7%
            AND C7_XIDME = %exp:cPurchaseOrderId%
            AND SC7.%notdel%
        EndSql

        VarInfo("GetLastQuery()", GetLastQuery()[2])

        If !(cTemp)->(Eof())
			cPurchaseOrderId := (cTemp)->C7_NUM
            VarInfo("cPurchaseOrderId =>", cPurchaseOrderId)
            lRet := .T.
		Else
			cPurchaseOrderId := ""
            VarInfo("cPurchaseOrderId =>", cPurchaseOrderId)
        EndIf

        (cTemp)->( dbCloseArea() )

Return lRet
/*/{Protheus.doc} getRequestById
Obtém o número da solicitação de compra (C1_NUM) a partir do IDME (C1_XIDME)
@type function
@version 1.0  
@author Claudio Donizete
@since       03/09/2025
@param requestId, character, IDME da solicitação de compra
*/
Method getRequestById(requestId) Class PedidosDeCompra
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
/*/{Protheus.doc} PreValid
PreValida se o pedido de compra ja existe
@type function
@version 1.0  
@author Claudio Donizete
@since       03/09/2025
@param aDados, array, Array com os dados do pedido de compra
@param aItems, array, Array com os itens do pedido de compra   
@param oResponse, object, Objeto de resposta da API
@param nOperation, numeric, Operação (3-Inserir, 5-Reverter)
*/
Method PreValid(aDados,aItems,oResponse,nOperation) Class PedidosDeCompra
Local cPOIdMe := ::GetIdMePurchaseOrder(aDados)   
Local lRet := .T.
Local cPONumberErp := cPOIdMe

    VarInfo("cPOIdMe", cPOIdMe)
    
    If ::ExistPurchaseOrder(@cPONumberErp)
        VarInfo("cPONumberErp", cPONumberErp)
        lRet := .F.
        oResponse['code'] := 7 
        oResponse['status'] := 400
        oResponse['message'] := If(nOperation==OPERATION_REVERT,"REVERT","")+" failed"
        oResponse['detailedMessage'] := "Purchase Order already exists, purchaseordernumber -> " + cPONumberErp
    EndIf

Return lRet
/*/{Protheus.doc} GetIdMePurchaseOrder
Obtém o IDME do pedido de compra (C7_XIDME) a partir dos dados enviados no body
@type function
@version 1.0  
@author Claudio Donizete
@since       03/09/2025
@param aDados, array, Array com os dados do pedido de compra
@return character, IDME do pedido de compra
*/
Method GetIdMePurchaseOrder(aDados) Class PedidosDeCompra
Local cRet := ""
Local nPosXIdMe

    If SC7->(FieldPos("C7_XIDME")) > 0 
        nPosXIdMe := Ascan(aDados, {|e| Upper(e[FIELD_NAME]) == "C7_XIDME"})
        If nPosXIdMe > 0
            cRet := aDados[nPosXIdMe,FIELD_CONTENT]
        EndIf
    EndIf

Return cRet    
