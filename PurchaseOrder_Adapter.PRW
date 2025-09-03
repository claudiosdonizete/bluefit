#include 'totvs.ch'
#include 'parmtype.ch'

#define FIELD_JSONDISPLAY       1
#define FIELD_NAMEQUERY         2
#define FIELD_JSONFIELDDISPLAY  3
#define FIELD_JSONFIXED         4
#define FIELD_STRUCT            5

/*/{Protheus.doc} PurchaseOrderAdapter
Classe de pedido de compra para utilização do FWAdapterBaseV2
@type class
@version 1.0
@author Claudio Donizete
@since 29/08/2025
/*/
CLASS PurchaseOrderAdapter FROM FWAdapterBaseV2
	PRIVATE DATA cAliasQueryTrb AS CHARACTER

	METHOD New()
	METHOD getListPurchaseOrders()
	METHOD getFields()
	METHOD GetFItems()
	METHOD GetQuery()

	PROTECTED METHOD ValueToJSON(cField, xValue)
    PROTECTED METHOD RowToJSON(cAlias, aFields, lEmpty)
    PROTECTED METHOD GetJsonDocItems(cPurchaseOrder)

EndClass


/*/{Protheus.doc} PurchaseOrderAdapter::New
Criacao do metodo PurchaseOrderAdapter
@type method
@version 1.0
@author Claudio Donizete
@since 29/08/2025
@param cVerb, character, Verbo usado
/*/
Method New( cVerb ) CLASS PurchaseOrderAdapter
	_Super:New( cVerb, .T. )
	::cAliasQueryTrb := ""
Return


/*/{Protheus.doc} PurchaseOrderAdapter::getListPurchaseOrder
Metodo de listagem dos pedidos de compra
@type method
@version 1.0
@author Claudio Donizete
@since 29/08/2025
/*/
Method getListPurchaseOrders() CLASS PurchaseOrderAdapter
	Local aArea     AS ARRAY
	Local cWhere    AS CHAR

	aArea   := FwGetArea()

	//-- Adiciona o mapa de campos Json/ResultSet
	AddMapFields( self, ::GetFields() )

	//-- Informa a Query a ser utilizada pela API
	::SetQuery( ::GetQuery() )

	//-- Informa a clausula Where da Query
	cWhere := " SC7.C7_FILIAL = '"+ FWxFilial('SC7') +"' AND SC7.D_E_L_E_T_ = ' ' AND ( (C7_QUANT-C7_QUJE) > 0 ) AND C7_RESIDUO = ' '"

	::SetWhere( cWhere )

	//-- Informa a ordenacao padrao a ser Utilizada pela Query
	::SetOrder( "C7_NUM" )

	//-- Executa a consulta, se retornar .T. tudo ocorreu conforme esperado
	If ::Execute()
		//-- Gera o arquivo Json com o retorno da Query
		::FillGetResponse()
	EndIf

	FwrestArea(aArea)

Return
/*/{Protheus.doc} AddMapFields
Adiciona campo a campo as configuracoes de campos utilizado no Adapter
@type function
@version 1.0
@author Claudio Donizete
@since 29/08/2025
@param oSelf, object, objeto WS
/*/
Static Function AddMapFields( oSelf, aFields)
Local nLen := Len(aFields)
Local nX

  For nX := 1 To nLen
      oSelf:AddMapFields( aFields[nX,FIELD_JSONDISPLAY],;
                          aFields[nX,FIELD_NAMEQUERY],;
                          aFields[nX,FIELD_JSONFIELDDISPLAY],;
                          aFields[nX,FIELD_JSONFIXED],;
                          aFields[nX,FIELD_STRUCT])		
  Next

return 

Method getFields() CLASS PurchaseOrderAdapter
Local aFields := {} 

    Aadd(aFields, { "branchid"           , "C7_FILIAL" , .T., .T., {"C7_FILIAL" , FwGetSX3Cache("C7_FILIAL", "X3_TIPO") , FwGetSX3Cache("C7_FILIAL", "X3_TAMANHO") , FwGetSX3Cache("C7_FILIAL", "X3_DECIMAL") } } )
    Aadd(aFields, { "purchaseordernumber", "C7_NUM"    , .T., .T., {"C7_NUM"    , FwGetSX3Cache("C7_NUM", "X3_TIPO")    , FwGetSX3Cache("C7_NUM", "X3_TAMANHO")    , FwGetSX3Cache("C7_NUM", "X3_DECIMAL")    } } )
    Aadd(aFields, { "suppliercode"       , "C7_FORNECE", .T., .T., {"C7_FORNECE", FwGetSX3Cache("C7_FORNECE", "X3_TIPO"), FwGetSX3Cache("C7_FORNECE", "X3_TAMANHO"), FwGetSX3Cache("C7_FORNECE", "X3_DECIMAL")} } )
    Aadd(aFields, { "supplierunit"       , "C7_LOJA"   , .T., .T., {"C7_LOJA"   , FwGetSX3Cache("C7_LOJA", "X3_TIPO")   , FwGetSX3Cache("C7_LOJA", "X3_TAMANHO")   , FwGetSX3Cache("C7_LOJA", "X3_DECIMAL")   } } )
    Aadd(aFields, { "issuedate"          , "C7_EMISSAO", .T., .T., {"C7_EMISSAO", "C"                                   , FwGetSX3Cache("C7_EMISSAO", "X3_TAMANHO"), FwGetSX3Cache("C7_EMISSAO", "X3_DECIMAL")} } )
    
	Aadd(aFields, { "contact"   		 , "C7_CONTATO", .T., .T., {"C7_CONTATO", FwGetSX3Cache("C7_CONTATO", "X3_TIPO"), FwGetSX3Cache("C7_CONTATO", "X3_TAMANHO"), FwGetSX3Cache("C7_CONTATO", "X3_DECIMAL")} } )
    Aadd(aFields, { "paymentterm"   	 , "C7_COND"   , .T., .T., {"C7_COND"   , FwGetSX3Cache("C7_COND", "X3_TIPO")   , FwGetSX3Cache("C7_COND", "X3_TAMANHO")   , FwGetSX3Cache("C7_COND", "X3_DECIMAL")   } } )
    Aadd(aFields, { "branchdelivery"     , "C7_FILENT" , .T., .T., {"C7_FILENT" , FwGetSX3Cache("C7_FILENT", "X3_TIPO") , FwGetSX3Cache("C7_FILENT", "X3_TAMANHO") , FwGetSX3Cache("C7_FILENT", "X3_DECIMAL") } } )
    Aadd(aFields, { "currency"           , "C7_MOEDA"  , .T., .T., {"C7_MOEDA"  , FwGetSX3Cache("C7_MOEDA", "X3_TIPO")  , FwGetSX3Cache("C7_MOEDA", "X3_TAMANHO")  , FwGetSX3Cache("C7_MOEDA", "X3_DECIMAL")  } } )
    Aadd(aFields, { "currencyrate"       , "C7_TXMOEDA", .T., .T., {"C7_TXMOEDA", FwGetSX3Cache("C7_TXMOEDA", "X3_TIPO"), FwGetSX3Cache("C7_TXMOEDA", "X3_TAMANHO"), FwGetSX3Cache("C7_TXMOEDA", "X3_DECIMAL")} } )
    
    If SC7->(FieldPos("C7_XIDME")) > 0
		Aadd(aFields, { "purchaserorderidme"   , "C7_XIDME" , .T., .T., {"C7_XIDME" , FwGetSX3Cache("C7_XIDME", "X3_TIPO") , FwGetSX3Cache("C7_XIDME", "X3_TAMANHO") , FwGetSX3Cache("C7_XIDME", "X3_DECIMAL") } } )
	EndIf

	// Aadd(aFields, { "productcode"        , "C7_PRODUTO", .T., .T., {"C7_PRODUTO", FwGetSX3Cache("C7_PRODUTO", "X3_TIPO"), FwGetSX3Cache("C7_PRODUTO", "X3_TAMANHO"), FwGetSX3Cache("C7_PRODUTO", "X3_DECIMAL")} } )
    // Aadd(aFields, { "quantity"           , "C7_QUANT"  , .T., .T., {"C7_QUANT"  , FwGetSX3Cache("C7_QUANT", "X3_TIPO")  , FwGetSX3Cache("C7_QUANT", "X3_TAMANHO")  , FwGetSX3Cache("C7_QUANT", "X3_DECIMAL")  } } )
    // Aadd(aFields, { "measurementunit"    , "C7_UM"     , .T., .T., {"C7_UM"     , FwGetSX3Cache("C7_UM", "X3_TIPO")     , FwGetSX3Cache("C7_UM", "X3_TAMANHO")     , FwGetSX3Cache("C7_UM", "X3_DECIMAL")     } } )
    // Aadd(aFields, { "itemunitprice"      , "C7_PRECO"  , .T., .T., {"C7_PRECO"  , FwGetSX3Cache("C7_PRECO", "X3_TIPO")  , FwGetSX3Cache("C7_PRECO", "X3_TAMANHO")  , FwGetSX3Cache("C7_PRECO", "X3_DECIMAL")  } } )
    // Aadd(aFields, { "itemtotalvalue"     , "C7_TOTAL"  , .T., .T., {"C7_TOTAL"  , FwGetSX3Cache("C7_TOTAL", "X3_TIPO")  , FwGetSX3Cache("C7_TOTAL", "X3_TAMANHO")  , FwGetSX3Cache("C7_TOTAL", "X3_DECIMAL")  } } )
    // Aadd(aFields, { "qtyalreadydelivered", "C7_QUJE"   , .T., .T., {"C7_QUJE"   , FwGetSX3Cache("C7_QUJE", "X3_TIPO")   , FwGetSX3Cache("C7_QUJE", "X3_TAMANHO")   , FwGetSX3Cache("C7_QUJE", "X3_DECIMAL")   } } )
    // Aadd(aFields, { "poelimresidue"      , "C7_RESIDUO", .T., .T., {"C7_RESIDUO", FwGetSX3Cache("C7_RESIDUO", "X3_TIPO"), FwGetSX3Cache("C7_RESIDUO", "X3_TAMANHO"), FwGetSX3Cache("C7_RESIDUO", "X3_DECIMAL")} } )
    // Aadd(aFields, { "productdescription" , "C7_DESCRI" , .T., .T., {"C7_DESCRI" , FwGetSX3Cache("C7_DESCRI", "X3_TIPO") , FwGetSX3Cache("C7_DESCRI", "X3_TAMANHO") , FwGetSX3Cache("C7_DESCRI", "X3_DECIMAL") } } )
    // Aadd(aFields, { "ipitaxrate"         , "C7_IPI"    , .T., .T., {"C7_IPI"    , FwGetSX3Cache("C7_IPI", "X3_TIPO")    , FwGetSX3Cache("C7_IPI", "X3_TAMANHO")    , FwGetSX3Cache("C7_IPI", "X3_DECIMAL")    } } )

	Aadd(aFields, { 'purchaseorderitems' , 'C7_NUM'    , .T., .T.,  {'C7_NUM'    , FwGetSx3Cache("C7_NUM","X3_TIPO")    ,  FwGetSx3Cache("C7_NUM","X3_TAMANHO"), 0 }     } )

Return aFields

/*/{Protheus.doc} PurchaseOrderAdapter::GetFItems
Metodo para retornar os campos dos itens de um documento, que será usado na query para recuperar os campos necessários. 
@type method
@author Claudio Donizete
@since 30/08/2025
@return aFields => Array de campos dos itens de um documento
/*/
Method GetFItems() CLASS PurchaseOrderAdapter
Local aFields := {}

    Aadd(aFields, { "purchaseorderitem"   , "C7_ITEM"    , .T., .T.,  {"C7_ITEM"   , FwGetSX3Cache("C7_ITEM", "X3_TIPO")   , FwGetSX3Cache("C7_ITEM", "X3_TAMANHO")   , FwGetSX3Cache("C7_ITEM", "X3_DECIMAL")   } } )
	Aadd(aFields, { 'productCode'         , 'C7_PRODUTO' , .T., .T.,  {'C7_PRODUTO', FwGetSx3Cache("C7_PRODUTO","X3_TIPO")    ,  FwGetSx3Cache("C7_PRODUTO","X3_TAMANHO"), 0 }    } )
    Aadd(aFields, { 'productDescription'  , 'B1_DESC'    , .T., .T.,  {'B1_DESC'   , FwGetSx3Cache("B1_DESC","X3_TIPO")   ,  FwGetSx3Cache("B1_DESC","X3_TAMANHO"), 0 }} )
    Aadd(aFields, { 'warehouseCode'       , 'C7_LOCAL'   , .T., .T.,  {'C7_LOCAL'  , FwGetSx3Cache("C7_LOCAL","X3_TIPO")  ,  FwGetSx3Cache("C7_LOCAL","X3_TAMANHO"), 0 }  } )
    Aadd(aFields, { 'warehousDescription' , 'NNR_DESCRI' , .T., .T.,  {'NNR_DESCRI', FwGetSx3Cache("NNR_DESCRI","X3_TIPO"),  FwGetSx3Cache("NNR_DESCRI","X3_TAMANHO"), 0 }  } )

	Aadd(aFields, { "quantity"           , "C7_QUANT"  , .T., .T., {"C7_QUANT"  , FwGetSX3Cache("C7_QUANT", "X3_TIPO")  , FwGetSX3Cache("C7_QUANT", "X3_TAMANHO")  , FwGetSX3Cache("C7_QUANT", "X3_DECIMAL")  } } )
    Aadd(aFields, { "measurementunit"    , "C7_UM"     , .T., .T., {"C7_UM"     , FwGetSX3Cache("C7_UM", "X3_TIPO")     , FwGetSX3Cache("C7_UM", "X3_TAMANHO")     , FwGetSX3Cache("C7_UM", "X3_DECIMAL")     } } )
    Aadd(aFields, { "itemunitprice"      , "C7_PRECO"  , .T., .T., {"C7_PRECO"  , FwGetSX3Cache("C7_PRECO", "X3_TIPO")  , FwGetSX3Cache("C7_PRECO", "X3_TAMANHO")  , FwGetSX3Cache("C7_PRECO", "X3_DECIMAL")  } } )
    Aadd(aFields, { "itemtotalvalue"     , "C7_TOTAL"  , .T., .T., {"C7_TOTAL"  , FwGetSX3Cache("C7_TOTAL", "X3_TIPO")  , FwGetSX3Cache("C7_TOTAL", "X3_TAMANHO")  , FwGetSX3Cache("C7_TOTAL", "X3_DECIMAL")  } } )
    Aadd(aFields, { "qtyalreadydelivered", "C7_QUJE"   , .T., .T., {"C7_QUJE"   , FwGetSX3Cache("C7_QUJE", "X3_TIPO")   , FwGetSX3Cache("C7_QUJE", "X3_TAMANHO")   , FwGetSX3Cache("C7_QUJE", "X3_DECIMAL")   } } )
    Aadd(aFields, { "poelimresidue"      , "C7_RESIDUO", .T., .T., {"C7_RESIDUO", FwGetSX3Cache("C7_RESIDUO", "X3_TIPO"), FwGetSX3Cache("C7_RESIDUO", "X3_TAMANHO"), FwGetSX3Cache("C7_RESIDUO", "X3_DECIMAL")} } )
    Aadd(aFields, { "productdescription" , "C7_DESCRI" , .T., .T., {"C7_DESCRI" , FwGetSX3Cache("C7_DESCRI", "X3_TIPO") , FwGetSX3Cache("C7_DESCRI", "X3_TAMANHO") , FwGetSX3Cache("C7_DESCRI", "X3_DECIMAL") } } )
    Aadd(aFields, { "ipitaxrate"         , "C7_IPI"    , .T., .T., {"C7_IPI"    , FwGetSX3Cache("C7_IPI", "X3_TIPO")    , FwGetSX3Cache("C7_IPI", "X3_TAMANHO")    , FwGetSX3Cache("C7_IPI", "X3_DECIMAL")    } } )
	Aadd(aFields, { "deliverydate"       , "C7_DATPRF" , .T., .T., {"C7_DATPRF" , "C"                                   , FwGetSX3Cache("C7_DATPRF", "X3_TAMANHO") , FwGetSX3Cache("C7_DATPRF", "X3_DECIMAL") } } )
	Aadd(aFields, { "purchaserequestid"  , "C7_NUMSC"  , .T., .T., {"C7_NUMSC"  , FwGetSX3Cache("C7_NUMSC", "X3_TIPO")  , FwGetSX3Cache("C7_NUMSC", "X3_TAMANHO")  , FwGetSX3Cache("C7_NUMSC", "X3_DECIMAL")  } } )
	Aadd(aFields, { "purchaserequestitem", "C7_ITEMSC" , .T., .T., {"C7_ITEMSC" , FwGetSX3Cache("C7_ITEMSC", "X3_TIPO") , FwGetSX3Cache("C7_ITEMSC", "X3_TAMANHO") , FwGetSX3Cache("C7_ITEMSC", "X3_DECIMAL") } } )

Return aFields


/*/{Protheus.doc} GetQuery
Query que sera utilizado no metodo SetQuery
@type function
@version 1.0
@author Claudio Donizete
@since 29/08/2025
@return character, Retorna query
/*/
Method GetQuery() CLASS PurchaseOrderAdapter
	Local cQuery AS CHARACTER

	cQuery := " SELECT #QueryFields# "
	cQuery += "     FROM " + RetSqlName( 'SC7' ) + " SC7 "
	cQuery += " WHERE #QueryWhere# "

Return cQuery

/*/{Protheus.doc} PurchaseOrderAdapter::RowToJSON
Metodo de suporte na geração do retorno, no caso da trasnferencia, precisa agrupar por documento
@type method
@author Claudio Donizete
@since 30/08/2025
@param cAlias, character, Alias
@param aFields, array, Campos
@param lEmpty, logical, Empty
@return variant, Retorno do metodo super
/*/
METHOD RowToJSON(cAlias, aFields, lEmpty) CLASS PurchaseOrderAdapter
    ::cAliasQueryTrb := cAlias
Return _Super:RowToJSON(cAlias, aFields, lEmpty)

/*/{Protheus.doc} PurchaseOrderAdapter::ValueToJSON
Metodo para tratar os valores dos items do documento de transferencia
@type method
@author Claudio Donizete
@since 30/08/2025
@param cField, character, Campo
@param xValue, variant, Valor
@return variant, Valor do atributo
/*/
METHOD ValueToJSON(cField, xValue) CLASS PurchaseOrderAdapter
Local xRet	:= _Super:ValueToJSON(cField, xValue)
    If Lower(AllTrim(cField)) == "purchaseorderitems" .And. Select(::cAliasQueryTrb) > 0
        xRet := ::GetJsonDocItems((::cAliasQueryTrb)->C7_NUM)
    EndIf
Return xRet
/*/{Protheus.doc} PurchaseOrderAdapter::GetJsonDocItems
Retorna os items do documento de transferencia
@type method
@author Claudio Donizete
@since 20/4/2023
@param cDocument = Documento de transferencia
@return array, array de JSON ( objetos especiais do tipo JSON (clase JSONOBject) )
/*/
METHOD GetJsonDocItems(cPurchaseOrder) CLASS PurchaseOrderAdapter
Local aRet			:= {}

Local jItem as Object
Local aFieldsDoc    := ::GetFItems()
Local nX   
Local nLen          
Local cAliasQry     := GetNextAlias()
Local aArea         := GetArea()
Local cCampos       := ""

    nLen          := Len(aFieldsDoc)

    // monta os campos da query, baseado no GetFItems
    For nX := 1 To nLen
        cCampos += aFieldsDoc[nX,FIELD_NAMEQUERY]
        If nX < nLen
            cCampos += ","
        EndIf
    Next

    cCampos := "%" + cCampos + "%"

    BeginSql Alias cAliasQry

        SELECT  %exp:cCampos% 
          FROM %table:SC7% SC7

        LEFT JOIN %table:SB1% SB1 ON B1_FILIAL = %xFilial:SB1% AND B1_COD = C7_PRODUTO AND SB1.%notDel%
		LEFT JOIN %table:NNR% NNR ON NNR_FILIAL = %xFilial:NNR% AND NNR_CODIGO = C7_LOCAL AND NNR.%notDel%
    
         WHERE C7_FILIAL = %xFilial:SC7%
               AND C7_NUM=%exp:cPurchaseOrder%
               AND SC7.%notDel%

    EndSql

  	While !(cAliasQry)->(Eof()) 
		jItem := JSONObject():New()
        
        For nX := 1 To nLen
  		    jItem[lower(aFieldsDoc[nX,FIELD_JSONDISPLAY])] := (cAliasQry)->&(aFieldsDoc[nX,FIELD_NAMEQUERY])
        Next

   		aAdd(aRet, jItem)
        (cAliasQry)->(DBSkip())
        
	End
  
    (cAliasQry)->(DBCloseArea())
    RestArea(aArea)
    FreeObj(jItem)
    aSize(aArea,0)

Return aRet

