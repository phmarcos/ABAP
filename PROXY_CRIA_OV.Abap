    METHOD zii_si_administrar_fatura_sync~si_administrar_fatura_sync_inb.
*----------------------------------------------------------------------*
*                                                                 *
*----------------------------------------------------------------------*
* PROJETO : Criação de Fatura Vetor X SAP - VAMOS                      *
* OBJETIVO : Criar ov e faturamento automatico                         *
* FUNCIONAL :                 *
* AUTOR :                    *
* DATA: :                                                 *
* TIPO : proxy                                                         *
* DEPENDENCIA: VA01, VA02, VF01, VF11                                  *
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*
* HISTÓRICO DE MODIFICAÇÕES *
*----------------------------------------------------------------------*
* Data – Autor - Chamado *
* DD/MM/AAAA – X-AUTOR—X – X--Chamado--X *
* DD/MM/AAAA – X- AUTOR—X – X--Chamado--X *
*----------------------------------------------------------------------*

      DATA: ls_zbrsdt0188 TYPE zbrsdt0188,

            it_ret_est    TYPE TABLE OF bapireturn1,
            it_success    TYPE TABLE OF bapivbrksuccess,
            lv_salesdoc   TYPE bapivbeln-vbeln,
            lv_contract   TYPE vbeln,
            lv_zversion   TYPE numc5,
            lv_fat_erro   TYPE c,
            lv_fatura(10) TYPE c,
            lv_bill_doc   TYPE bapivbrksuccess-bill_doc.

      CONSTANTS: lc_intcod(03)    TYPE c VALUE '074',
                 lc_numreg        TYPE zbrinted_numreg  VALUE '00001',
                 lc_cond_type(04) TYPE c VALUE 'ZP01',
                 lc_text_id(04)   TYPE c VALUE 'Z005',
                 lc_incoterms(03) TYPE c VALUE 'FOB',
                 lc_currency(03)  TYPE c VALUE 'BRL'.

      IF input-mt_administrar_fatura_req IS INITIAL.
        output-mt_administrar_fatura_resp-code              = '99'.
        output-mt_administrar_fatura_resp-id_transacao      = input-mt_administrar_fatura_req-id_transacao.
        output-mt_administrar_fatura_resp-nro_vetor         = input-mt_administrar_fatura_req-nro_vetor.
        output-mt_administrar_fatura_resp-message           = TEXT-e98.
        EXIT.
      ENDIF.
      "Cabecalho ZINT
      PERFORM sel_ultima_versao_interface IN PROGRAM zbrintr0010
        USING lc_intcod
              input-mt_administrar_fatura_req-id_transacao
        CHANGING lv_zversion.

      ls_zbrsdt0188-zintcod  = lc_intcod.
      ls_zbrsdt0188-zidmsg   = input-mt_administrar_fatura_req-id_transacao.
      ls_zbrsdt0188-zversion = lv_zversion + 1.
      ls_zbrsdt0188-znumreg  = lc_numreg.
      ls_zbrsdt0188-dtpropi  = sy-datum.
      ls_zbrsdt0188-uzpropi  = sy-uzeit.

      CASE input-mt_administrar_fatura_req-tipo_evento.
        WHEN '1'. "Criação
          SELECT SINGLE zidmsg
            FROM zbrsdt0188
            INTO @DATA(lv_idmsg)
           WHERE zidmsg = @input-mt_administrar_fatura_req-id_transacao.

          IF sy-subrc = 0.
            output-mt_administrar_fatura_resp-code              = '91'.
            output-mt_administrar_fatura_resp-id_transacao      = input-mt_administrar_fatura_req-id_transacao.
            output-mt_administrar_fatura_resp-nro_vetor         = input-mt_administrar_fatura_req-nro_vetor.
            output-mt_administrar_fatura_resp-message           = TEXT-e91.

            EXIT.
          ENDIF.
          IF input-mt_administrar_fatura_req-nro_contrato IS NOT INITIAL.

            lv_contract = |{ input-mt_administrar_fatura_req-nro_contrato ALPHA = IN }|.

            ls_bapi_view-header   = abap_true.
            ls_bapi_view-item     = abap_true.
            ls_bapi_view-business = abap_true.
            ls_bapi_view-partner  = abap_true.
            ls_bapi_view-sdcond   = abap_true.

            it_documents = VALUE #( ( vbeln =  lv_contract ) ).

            CALL FUNCTION 'BAPISDORDER_GETDETAILEDLIST'
              EXPORTING
                i_bapi_view          = ls_bapi_view
              TABLES
                sales_documents      = it_documents
                order_headers_out    = it_header_out
                order_items_out      = it_items_out
                order_business_out   = it_busi_out
                order_partners_out   = it_partn_out
                order_conditions_out = it_cond_out.

            IF it_header_out IS NOT INITIAL AND it_items_out IS NOT INITIAL.
              DATA(ls_header_out) = it_header_out[ 1 ].

              ls_header_in-doc_type   = input-mt_administrar_fatura_req-tipo_ord_vendas.
              ls_header_in-sales_org  = ls_header_out-sales_org.
              ls_header_in-distr_chan = ls_header_out-distr_chan.
              ls_header_in-division   = ls_header_out-division.
              ls_header_in-pmnttrms   = it_busi_out[ 1 ]-pmnttrms.
              ls_header_in-ref_doc    = |{ input-mt_administrar_fatura_req-nro_contrato ALPHA = IN }|.
              ls_header_in-refdoc_cat = ls_header_out-sd_doc_cat.
              ls_header_in-incoterms1 = lc_incoterms.
              ls_header_in-incoterms2 = lc_incoterms.
              ls_header_in-currency   = lc_currency.

              ls_header_inx-doc_type   = abap_true.
              ls_header_inx-sales_org  = abap_true.
              ls_header_inx-distr_chan = abap_true.
              ls_header_inx-division   = abap_true.
              ls_header_inx-ref_doc    = abap_true.
              ls_header_inx-refdoc_cat = abap_true.
              ls_header_inx-incoterms1 = abap_true.
              ls_header_inx-incoterms2 = abap_true.
              ls_header_inx-currency   = abap_true.

              TRY .
                  it_items_in = VALUE #(
                    FOR ls_items IN input-mt_administrar_fatura_req-itens INDEX INTO index (
                      itm_number   = index * 10
                      material     = |{ ls_items-material ALPHA = IN }|
                      target_qty   = ls_items-qtd_material
                      target_qu    = 'UN'
                      incoterms1   = ls_items-incoterms
                      incoterms2   = ls_items-incoterms
                      profit_ctr   = ls_items-centro_expedicao
                      purch_no_c   = ls_items-modelo
                      matl_group   = VALUE #( it_items_out[ itm_number = index * 10 ]-matl_group )
                      plant        = VALUE #( it_items_out[ itm_number = index * 10 ]-plant )
                      tax_class1   = VALUE #( it_items_out[ itm_number = index * 10 ]-tax_class1 )
                      taxlawicms   = VALUE #( it_items_out[ itm_number = index * 10 ]-taxlawicms )
                      sd_taxcode   = VALUE #( it_items_out[ itm_number = index * 10 ]-sd_taxcode )
                      taxlawcofins = VALUE #( it_items_out[ itm_number = index * 10 ]-taxlawcofins )
                      taxlawpis    = VALUE #( it_items_out[ itm_number = index * 10 ]-taxlawpis )
                    ) ).
                CATCH cx_sy_itab_line_not_found.
                  it_items_in = VALUE #(
                  FOR ls_items IN input-mt_administrar_fatura_req-itens INDEX INTO index (
                    itm_number   = index * 10
                    material     = |{ ls_items-material ALPHA = IN }|
                    target_qty   = ls_items-qtd_material
                    target_qu    = 'UN'
                    incoterms1   = ls_items-incoterms
                    incoterms2   = ls_items-incoterms
                    profit_ctr   = ls_items-centro_expedicao
                    purch_no_c   = ls_items-modelo
                    matl_group   = VALUE #( it_items_out[ 1 ]-matl_group )
                    plant        = VALUE #( it_items_out[ 1 ]-plant )
                    tax_class1   = VALUE #( it_items_out[ 1 ]-tax_class1 )
                    taxlawicms   = VALUE #( it_items_out[ 1 ]-taxlawicms )
                    sd_taxcode   = VALUE #( it_items_out[ 1 ]-sd_taxcode )
                    taxlawcofins = VALUE #( it_items_out[ 1 ]-taxlawcofins )
                    taxlawpis    = VALUE #( it_items_out[ 1 ]-taxlawpis )
                  ) ).
              ENDTRY.

              it_items_inx = VALUE #(
                FOR ls_items_in IN it_items_in (
                  itm_number   = ls_items_in-itm_number
                  material     = abap_true
                  target_qty   = abap_true
                  target_qu    = abap_true
                  incoterms1   = abap_true
                  incoterms2   = abap_true
                  profit_ctr   = abap_true
                  purch_no_c   = abap_true
                  matl_group   = abap_true
                  plant        = abap_true
                  tax_class1   = abap_true
                  taxlawicms   = abap_true
                  sd_taxcode   = abap_true
                  taxlawcofins = abap_true
                  taxlawpis    = abap_true ) ).

              it_partn_in = VALUE #( FOR ls_partner IN it_partn_out
                ( partn_role = ls_partner-partn_role partn_numb = ls_partner-customer ) ).

              it_sched_in = VALUE #(
                FOR ls_items_in IN it_items_in INDEX INTO index (
                  itm_number = ls_items_in-itm_number
                  sched_line = index
                  req_qty    = ls_items_in-target_qty ) ).
              it_sched_inx = VALUE #(
                FOR ls_sched IN it_sched_in (
                  itm_number = ls_sched-itm_number
                  sched_line = ls_sched-sched_line
                  req_qty    = abap_true ) ).

              it_cond_in = VALUE #(
                FOR ls_items_in IN it_items_in INDEX INTO index (
                  itm_number = ls_items_in-itm_number
                  cond_type  = lc_cond_type
                  currency   = lc_currency
                  cond_value = VALUE #( input-mt_administrar_fatura_req-itens[ index ]-preco  )
                  condtype   = VALUE #( it_cond_out[ cond_type = lc_cond_type ]-condtype OPTIONAL ) ) ).

              it_cond_inx = VALUE #(
                FOR ls_conds IN it_cond_inx (
                  itm_number = ls_conds-itm_number
                  cond_type  = ls_conds-cond_type
                  updateflag = abap_true
                  cond_value = abap_true
                  currency   = abap_true ) ).

              DATA(lv_obs) = input-mt_administrar_fatura_req-obs.
              REPLACE ALL OCCURRENCES OF '\n' IN lv_obs WITH '#'.
              SPLIT lv_obs AT '#' INTO TABLE DATA(it_texts).

              DATA(lv_lines) = lines( it_items_in ).
              TRY .
                  it_order_txt = VALUE #(
                    FOR ls_text IN it_texts (
                      itm_number = VALUE #( it_items_in[ lv_lines ]-itm_number )
                      text_id    = lc_text_id
                      langu      = sy-langu
                      format_col = '*'
                      text_line  = ls_text
                     ) ).
                CATCH cx_sy_itab_line_not_found.
                  it_order_txt = VALUE #( ( itm_number = VALUE #( it_items_in[ lv_lines ]-itm_number )
                                            text_id    = lc_text_id
                                            langu      = sy-langu
                                            format_col = '*'
                                            text_line  = input-mt_administrar_fatura_req-obs ) ).
              ENDTRY.

              CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
                EXPORTING
                  order_header_in      = ls_header_in
                  order_header_inx     = ls_header_inx
                IMPORTING
                  salesdocument        = lv_salesdoc
                TABLES
                  return               = it_return
                  order_items_in       = it_items_in
                  order_items_inx      = it_items_inx
                  order_partners       = it_partn_in
                  order_schedules_in   = it_sched_in
                  order_schedules_inx  = it_sched_inx
                  order_conditions_in  = it_cond_in
                  order_conditions_inx = it_cond_inx
                  order_text           = it_order_txt.

              IF line_exists( it_return[ type = 'E' ] ).
                ls_zbrsdt0188-msgcod  = '99'.
                ls_zbrsdt0188-message = it_return[ type = 'E' ]-message.
              ELSE.

                CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                  EXPORTING
                    wait = abap_true.

                WAIT UP TO 3 SECONDS.

                me->criar_fatura(
                  EXPORTING
                      iv_salesdoc = lv_salesdoc
                  CHANGING
                      is_zbrsdt0188 = ls_zbrsdt0188 ).
                lv_fatura = ls_zbrsdt0188-fatura.
              ENDIF.
            ELSE.
              ls_zbrsdt0188-msgcod  = '90'.
              ls_zbrsdt0188-message = TEXT-e90.
            ENDIF.
          ELSE.
            ls_zbrsdt0188-msgcod  = '94'.
            ls_zbrsdt0188-message = TEXT-e94.
          ENDIF.

        WHEN '2'. "Estorno

          IF input-mt_administrar_fatura_req-nro_idfaturamento IS NOT INITIAL.

            lv_fatura = |{ input-mt_administrar_fatura_req-nro_idfaturamento ALPHA = IN }|.
            lv_bill_doc = lv_fatura.

            SELECT SINGLE contrato ordem
              FROM zbrsdt0188
              INTO ( lv_contract, lv_salesdoc )
             WHERE fatura = lv_bill_doc.

            CALL FUNCTION 'BAPI_BILLINGDOC_CANCEL1'
              EXPORTING
                billingdocument = lv_bill_doc
              TABLES
                return          = it_ret_est
                success         = it_success.

            IF it_success IS INITIAL.
              ls_zbrsdt0188-msgcod  = '99'.
              ls_zbrsdt0188-message = it_ret_est[ type = 'E' ]-message.
            ELSE.
              CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                EXPORTING
                  wait = abap_true.

              WAIT UP TO 3 SECONDS.
              ls_zbrsdt0188-fatura  = 'ESTORNADO'.
              IF lv_salesdoc IS INITIAL.
                ls_zbrsdt0188-msgcod  = '93'.
                ls_zbrsdt0188-message = TEXT-e93.
              ELSE.
                me->cancela_ov(
                  EXPORTING
                    iv_salesdoc = lv_salesdoc
                  CHANGING
                    is_zbrsdt0188 = ls_zbrsdt0188 ).
              ENDIF.
            ENDIF.
          ELSE.
            ls_zbrsdt0188-msgcod  = '95'.
            ls_zbrsdt0188-message = TEXT-e95.
          ENDIF.
        WHEN OTHERS.
      ENDCASE.

      ls_zbrsdt0188-contrato  = lv_contract.
      ls_zbrsdt0188-ordem     = lv_salesdoc.
      ls_zbrsdt0188-ov_erdat  = sy-datum.
      ls_zbrsdt0188-fat_erdat = sy-datum.

      MODIFY zbrsdt0188 FROM ls_zbrsdt0188.

      output-mt_administrar_fatura_resp-code              = ls_zbrsdt0188-msgcod.
      output-mt_administrar_fatura_resp-id_transacao      = input-mt_administrar_fatura_req-id_transacao.
      output-mt_administrar_fatura_resp-nro_vetor         = input-mt_administrar_fatura_req-nro_vetor.
      output-mt_administrar_fatura_resp-nro_idfaturamento = lv_fatura.
      output-mt_administrar_fatura_resp-message           = ls_zbrsdt0188-message.

    ENDMETHOD.