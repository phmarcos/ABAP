  METHOD criar_fatura.
    DATA: lv_fat_erro   TYPE c,
          lv_fatura(10) TYPE c.
*          it_ret_fat    TYPE TABLE OF zbrsds0121. " COMENTADO POIS PROCESSO NÃO ESTÁ EM PRD ainda.
    DATA: lv_return        TYPE bapi_msg,
          it_ret           TYPE TABLE OF bapiret1,
          it_success       TYPE TABLE OF bapivbrksuccess,
          it_billingdatain TYPE TABLE OF bapivbrk,
          wa_billingdatain TYPE bapivbrk.

    "Verifica se caiu em aprovação WF
*    SELECT SINGLE *                                      " COMENTADO POIS PROCESSO NÃO ESTÁ EM PRD ainda.
*      FROM zbrsdt0173
*      INTO @DATA(ls_itm)
*     WHERE ov EQ @iv_salesdoc.
*    IF sy-subrc = 0.
*      CALL FUNCTION 'ZBRSDMF_CRIAR_FATURA'
*        EXPORTING
*          i_ov      = iv_salesdoc
*          i_aprov   = sy-uname
*        IMPORTING
*          e_erro    = lv_fat_erro
*        TABLES
*          it_return = it_ret_fat.
*
*      IF lv_fat_erro IS NOT INITIAL.
*        is_zbrsdt0188-msgcod    = '99'.
*        is_zbrsdt0188-message   = TEXT-e96.
*      ELSE.
*        IF it_ret_fat IS NOT INITIAL.
*          SPLIT it_ret_fat[ 1 ]-message AT space INTO TABLE DATA(it_message).
*
*          lv_fatura = VALUE #( it_message[ 2 ] ).
*          is_zbrsdt0188-fatura    = lv_fatura.
*          is_zbrsdt0188-msgcod    = '0'.
*          is_zbrsdt0188-message   = TEXT-s00.
*        ELSE.
*          is_zbrsdt0188-msgcod    = '99'.
*          is_zbrsdt0188-message   = TEXT-e96.
*        ENDIF.
*      ENDIF.
*    ELSE.

      SELECT SINGLE vbtyp, auart, fkara
        FROM vbak
        INTO @DATA(ls_vbak)
       WHERE vbeln = @iv_salesdoc.

      IF sy-subrc = 0.
        wa_billingdatain-ref_doc_ca = ls_vbak-vbtyp.
        wa_billingdatain-doc_type   = ls_vbak-auart.
        wa_billingdatain-ordbilltyp = ls_vbak-fkara.
      ENDIF.
      wa_billingdatain-ref_doc    = iv_salesdoc.
      wa_billingdatain-orderid    = iv_salesdoc.
      wa_billingdatain-bill_date  = sy-datum.
      APPEND wa_billingdatain TO it_billingdatain.
* Criando o documento de faturamento
      CALL FUNCTION 'BAPI_BILLINGDOC_CREATEMULTIPLE'
        TABLES
          billingdatain = it_billingdatain
          return        = it_ret
          success       = it_success.
* Se não retornou nada de sucesso
      IF it_success IS INITIAL .
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

        READ TABLE it_ret INTO DATA(wa_ret) WITH KEY type = 'E'.
        IF sy-subrc EQ 0.
          is_zbrsdt0188-message = wa_ret-message.
          is_zbrsdt0188-msgcod    = '99'.
        ENDIF.
      ELSE.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = 'X'.

        READ TABLE it_success INTO DATA(wa_success) INDEX 1.
        is_zbrsdt0188-fatura    = wa_success-bill_doc.
        is_zbrsdt0188-msgcod    = '0'.
        is_zbrsdt0188-message   = TEXT-s00.
      ENDIF.
*    ENDIF.   " COMENTADO POIS PROCESSO NÃO ESTÁ EM PRD ainda.
  ENDMETHOD.