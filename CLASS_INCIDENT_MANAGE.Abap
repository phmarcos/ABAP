CLASS zcl_sophie_incident DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS check_user_auth
      IMPORTING
        iv_email          TYPE ad_smtpadr
        iv_userid         TYPE bapibname-bapibname
      RETURNING
        VALUE(iv_message) TYPE char255.

    METHODS incident_create
      IMPORTING
        !is_data_incident    TYPE zsophie_incident_create
      RETURNING
        VALUE(es_id_created) TYPE crmt_return_objects_struc .

    METHODS incident_query
      CHANGING
        !is_query_ret TYPE zret_inc .

  PROTECTED SECTION.


  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_guid,
        guid         TYPE crmd_orderadm_h-guid,
        process_type TYPE crmd_orderadm_h-process_type,
      END OF ty_guid,

      BEGIN OF ty_link,
        guid_hi TYPE crmd_link-guid_hi,
      END OF ty_link.

    TYPES tt_link TYPE STANDARD TABLE OF ty_link WITH DEFAULT KEY.

    DATA:
      lr_1o_api TYPE REF TO cl_ags_crm_1o_api,
      lr_1o_sd  TYPE REF TO zcl_crm_incident_api_sd.                "cl_ags_crm_1o_api_sd,

    DATA: gt_guid       TYPE TABLE OF ty_guid,
          gt_link       TYPE TABLE OF ty_link,
          gs_query      TYPE zret_inc,
          gv_qmode      TYPE char5,
          gv_by_company TYPE bool.

    DATA: gr_posting_date TYPE RANGE OF crmd_orderadm_h-posting_date,
          gr_proc_type    TYPE RANGE OF crmd_orderadm_h-process_type,
          gr_description  TYPE RANGE OF crmd_orderadm_h-description.

    CONSTANTS:
      BEGIN OF gc_mode,
        create  TYPE   crmt_mode   VALUE   'A',
        change  TYPE   crmt_mode   VALUE   'B',
        display TYPE   crmt_mode   VALUE   'C',
        delete  TYPE   crmt_mode   VALUE   'D',
      END OF gc_mode ,
      BEGIN OF gc_pfct,
        issuer    TYPE char8 VALUE '00000001',
        notifier  TYPE char8 VALUE 'SLFN0002',
        support   TYPE char8 VALUE 'SLFN0003',
        processor TYPE char8 VALUE 'SLFN0004',
      END OF gc_pfct,
      BEGIN OF gc_query_mode,
        by_incident TYPE char5 VALUE 'INCID',
        by_status   TYPE char5 VALUE 'STATU',
        by_postdate TYPE char5 VALUE 'PDATE',
        by_mtpperc  TYPE char5 VALUE 'MPERC',
        by_proctype TYPE char5 VALUE 'PTYPE',
        by_catid    TYPE char5 VALUE 'CATID',
        by_descr    TYPE char5 VALUE 'DESCR',
      END OF gc_query_mode,
      BEGIN OF gc_sla_perc,
        slapv TYPE char5 VALUE 'SLAPV',
      END OF gc_sla_perc,
      gc_category TYPE char3 VALUE 'SMS'.

    METHODS set_guid_query.

    METHODS query_basic
      RETURNING
        VALUE(et_query_basic) TYPE ztret_basic.

    METHODS query_creation
      RETURNING
        VALUE(es_creation) TYPE zret_creation.

    METHODS query_attend
      RETURNING
        VALUE(es_attend) TYPE zret_attend.

    METHODS query_sla
      RETURNING
        VALUE(es_sla) TYPE zret_sla.

    METHODS get_partner_guid
      IMPORTING
        !iv_user       TYPE bapibname-bapibname
      RETURNING
        VALUE(et_link) TYPE tt_link .

    METHODS filter_query
      IMPORTING
        !is_query_basic  TYPE LINE OF ztret_basic OPTIONAL
      RETURNING
        VALUE(ev_append) TYPE bool.

    METHODS init_query_mode
      IMPORTING
        !is_query TYPE zret_inc.

ENDCLASS.



CLASS ZCL_SOPHIE_INCIDENT IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SOPHIE_INCIDENT->CHECK_USER_AUTH
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_EMAIL                       TYPE        AD_SMTPADR
* | [--->] IV_USERID                      TYPE        BAPIBNAME-BAPIBNAME
* | [<-()] IV_MESSAGE                     TYPE        CHAR255
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD check_user_auth.
    DATA:lv_user      TYPE bapibname-bapibname,
         ls_user_data TYPE uslogond.

    IF iv_email IS NOT INITIAL AND iv_userid IS NOT INITIAL.
      CALL FUNCTION 'BBP_USER_GET_BY_EMAIL'
        EXPORTING
          e_mail          = iv_email
        IMPORTING
          user            = lv_user
        EXCEPTIONS
          no_user_found   = 1
          user_not_unique = 2
          OTHERS          = 3.
      IF sy-subrc <> 0.
        iv_message = text-e01. "Solmanloginerror
        EXIT.
      ENDIF.

      IF iv_userid EQ lv_user.
        CALL FUNCTION 'SUSR_USER_LOGONDATA_GET'
          EXPORTING
            user_name           = iv_userid
          IMPORTING
            user_logondata      = ls_user_data
          EXCEPTIONS
            user_name_not_exist = 1
            OTHERS              = 2.
        IF sy-subrc <> 0.
          iv_message = text-e01. "Solmanloginerror
        ELSEIF sy-datum > ls_user_data-gltgb AND ls_user_data-gltgb IS NOT INITIAL.
          iv_message = text-e02. "Solmanlogininactive
        ELSE.
          iv_message = text-s01. "Solmanloginsuccess
        ENDIF.
      ELSE.
        iv_message = text-e01."Solmanloginerror
      ENDIF.
    ELSE.
      iv_message = text-e01. "Solmanloginerror
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->FILTER_QUERY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_QUERY_BASIC                 TYPE        LINE OF ZTRET_BASIC(optional)
* | [<-()] EV_APPEND                      TYPE        BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD filter_query.
    CASE gv_qmode.
      WHEN gc_query_mode-by_status.
        IF is_query_basic-statustxt(5) = gs_query-user_status.
          ev_append = abap_true.
        ENDIF.

      WHEN gc_query_mode-by_mtpperc.
        IF ( gs_query-percent_mtp = gc_sla_perc-slapv AND
             lr_1o_sd->get_sla_status( )-mpt_perc >= 60 AND lr_1o_sd->get_sla_status( )-mpt_perc < 100 ). ">=60 <100
          ev_append = abap_true.
        ENDIF.

      WHEN gc_query_mode-by_catid.
        lr_1o_sd->get_subject( IMPORTING es_subject = DATA(ls_subject) ).
        IF ls_subject-cat_id = gs_query-cat_id.
          ev_append = abap_true.
        ENDIF.

      WHEN OTHERS.
        ev_append = abap_true.
    ENDCASE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->GET_PARTNER_GUID
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_USER                        TYPE        BAPIBNAME-BAPIBNAME
* | [<-()] ET_LINK                        TYPE        TT_LINK
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_partner_guid.
    DATA: lv_partner      TYPE bu_partner,
          lv_partner_guid TYPE but000-partner_guid.

    CALL FUNCTION 'CRM_ICM_BUPA_FOR_USER_GET'
      EXPORTING
        iv_uname           = iv_user
      IMPORTING
        ev_businesspartner = lv_partner.

    IF sy-subrc = 0.
      IF gv_by_company = abap_true.
        SELECT SINGLE partner1
          FROM but050
          INTO lv_partner
         WHERE partner2 = lv_partner
           AND reltyp  = 'BUR011'.
      ENDIF.
      CALL FUNCTION 'BBP_BUPA_GET_NUMBER'
        EXPORTING
          partner           = lv_partner
        IMPORTING
          ev_partner_guid   = lv_partner_guid
        EXCEPTIONS
          partner_not_valid = 1
          guid_not_valid    = 2
          no_input          = 3
          OTHERS            = 4.

      IF sy-subrc = 0.
        IF gv_by_company = abap_true.
          SELECT partner_guid, guid
           FROM crmd_partner
           INTO TABLE @DATA(lt_partner_guid)
          WHERE partner_no  = @lv_partner_guid.
        ELSE.
          SELECT partner_guid, guid
            FROM crmd_partner
            INTO TABLE @lt_partner_guid
           WHERE partner_fct = @gc_pfct-notifier
             AND partner_no  = @lv_partner_guid.
        ENDIF.
        IF sy-subrc = 0.
          SELECT guid_hi
            FROM crmd_link
            INTO TABLE et_link
             FOR ALL ENTRIES IN lt_partner_guid
           WHERE guid_set = lt_partner_guid-guid.
        ENDIF.
      ENDIF.
    ENDIF.
    IF sy-subrc <> 0.
      me->gs_query-message = text-e04.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SOPHIE_INCIDENT->INCIDENT_CREATE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA_INCIDENT               TYPE        ZSOPHIE_INCIDENT_CREATE
* | [<-()] ES_ID_CREATED                  TYPE        CRMT_RETURN_OBJECTS_STRUC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD incident_create.
    DATA: lt_msg            TYPE /tmwflow/mo_tt_msg,
          ls_msg            LIKE LINE OF lt_msg,
          ls_service_h      TYPE crmc_service_h,
          ls_subject        TYPE crmt_subject_com,
          lv_extid          TYPE dswpdtext30,
          ls_ib_det         TYPE ibap_head2,
          ls_ib_head        TYPE ibap_head1,
          ls_ib_comp_det    TYPE ibap_comp1,
          ls_ib_comp        TYPE ibap_dat1,
          ls_ibase_details  TYPE ibap_comp2,
          ls_refobj         TYPE crmt_refobj_com,
          lt_notes          TYPE TABLE OF aic_s_sap_notes,
          ls_notes          TYPE aic_s_sap_notes,
          lt_ret_objects    TYPE crmt_return_objects,
          lv_log_handle     TYPE balloghndl,
          it_partners       TYPE crmt_partner_comt,
          ls_partner        LIKE LINE OF it_partners,
          iv_partner        TYPE bu_partner,
          it_texts          TYPE crmt_text_comt,
          ls_texts          LIKE LINE OF it_texts,
          lv_texto          TYPE tline,
          es_error_occurred TYPE flag,
          iv_product_id     TYPE comt_product_id,
          iv_user_id        TYPE sy-uname.

*-----------------------------------------------------------------------
* create instance
*-----------------------------------------------------------------------

    lr_1o_sd = NEW zcl_crm_incident_api_sd(
                      iv_process_type = is_data_incident-proc_type
                      iv_process_mode = gc_mode-create ).


*-----------------------------------------------------------------------
* create order
*-----------------------------------------------------------------------

* set short text
    CALL METHOD lr_1o_sd->set_short_text
      EXPORTING
        iv_short_text = is_data_incident-short_text
      EXCEPTIONS
        OTHERS        = 1.
    IF sy-subrc NE 0.
      es_error_occurred = abap_true.
    ENDIF.

* set urgency and impact
    CALL METHOD lr_1o_sd->set_impact_urgency
      EXPORTING
        iv_impact  = is_data_incident-impact
        iv_urgency = is_data_incident-urgency
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc <> 0.
      es_error_occurred = abap_true.
    ENDIF.

* set category
    CALL METHOD lr_1o_sd->set_category
      EXPORTING
        iv_category = gc_category
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc NE 0.
      es_error_occurred = abap_true.
    ENDIF.

*-----------------------------------------------------------------------
* set subject profile, catalog, code groups and codes
*-----------------------------------------------------------------------
    CLEAR ls_service_h.

    CALL FUNCTION 'CRM_ORDER_SERVICE_H_SELECT_CB'
      EXPORTING
        iv_process_type = is_data_incident-proc_type
      IMPORTING
        es_service_h    = ls_service_h
      EXCEPTIONS
        entry_not_found = 1
        OTHERS          = 2.

    IF sy-subrc <> 0.
      es_error_occurred = abap_true.
      EXIT.
    ENDIF.

    ls_subject-subject_profile = ls_service_h-subject_profile.
    ls_subject-profile_type    = 'A'.

    IF is_data_incident-proc_type EQ 'ZMIN'.
      ls_subject-asp_id = 'CSC_IM_V1'.
    ELSE.
      ls_subject-asp_id = 'CSC_SVRQ_V1'.
    ENDIF.

    ls_subject-mode   = gc_mode-create.
    ls_subject-cat_id = is_data_incident-cat_id.
    ls_subject-katalog_type = 'D'.

    CALL METHOD lr_1o_sd->set_subject
      EXPORTING
        is_subject = ls_subject
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc NE 0.
      es_error_occurred = abap_true.
    ENDIF.

*-----------------------------------------------------------------------
* set reference object (IBase)
*-----------------------------------------------------------------------

* define product id
    DATA it_pruduct_id TYPE comt_product_id_tab.
    it_pruduct_id = cl_ai_crm_object_api=>get_object_ids_own( iv_uname = is_data_incident-user_id ).

    IF it_pruduct_id IS NOT INITIAL.
      iv_product_id = it_pruduct_id[ 1 ].
    ENDIF.

    IF iv_product_id IS NOT INITIAL.
* get ibase instance for product id
      ls_ibase_details-instance = cl_ai_crm_object_api=>get_ibase_component_for_object( iv_object_id = iv_product_id ).

*   read details of IBase component
      ls_ib_comp-instance = ls_ibase_details-instance.
      CALL FUNCTION 'CRM_IBASE_COMP_GET_DETAIL'
        EXPORTING
          i_comp        = ls_ib_comp
        IMPORTING
          e_comp_det    = ls_ibase_details
        EXCEPTIONS
          not_specified = 1
          doesnt_exist  = 2
          OTHERS        = 3.

      IF sy-subrc = 0.
        ls_refobj-ib_ibase     = ls_ibase_details-ibase.
        ls_refobj-ib_instance  = ls_ibase_details-instance.
        ls_refobj-text_ib_comp = ls_ibase_details-descr.
        ls_refobj-mode         = gc_mode-create.
        ls_refobj-product_id   = iv_product_id.
        ls_refobj-guid_object  = ls_ibase_details-object_guid.
      ENDIF.
    ENDIF. "/ iv_product_id is not initial

    CALL METHOD lr_1o_sd->set_refobj
      EXPORTING
        is_refobj = ls_refobj
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc NE 0.
      CLEAR ls_msg.
      es_error_occurred = abap_true.
      MOVE-CORRESPONDING sy TO ls_msg.
      APPEND ls_msg TO lt_msg.
    ENDIF.

*-----------------------------------------------------------------------
* set partner
*-----------------------------------------------------------------------

    iv_user_id = is_data_incident-user_id.

    CALL FUNCTION 'CRM_ICM_BUPA_FOR_USER_GET'
      EXPORTING
        iv_uname           = iv_user_id
      IMPORTING
        ev_businesspartner = iv_partner
      EXCEPTIONS
        bupa_not_found     = 1
        OTHERS             = 2.
    IF sy-subrc <> 0.
      es_error_occurred = abap_true.
    ENDIF.
    ls_partner-partner_no = iv_partner.
    ls_partner-partner_fct = gc_pfct-notifier.
    ls_partner-no_type = 'BP'.
    APPEND ls_partner TO it_partners.
    CLEAR ls_partner.

    CALL METHOD lr_1o_sd->set_partners
      EXPORTING
        it_partner = it_partners
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc NE 0.
      es_error_occurred = abap_true.
    ENDIF.

*-----------------------------------------------------------------------
* set text
*-----------------------------------------------------------------------

    ls_texts-text_object = 'CRM_ORDERH'.
    ls_texts-tdid = 'SU99'.
    ls_texts-mode = gc_mode-create.
    "lines text
    lv_texto-tdformat = '*'.
    lv_texto-tdline = is_data_incident-description.

    APPEND lv_texto TO ls_texts-lines.
    APPEND ls_texts TO it_texts.

    IF it_texts IS NOT INITIAL.
      CALL METHOD lr_1o_sd->set_texts
        EXPORTING
          it_text = it_texts
        EXCEPTIONS
          OTHERS  = 1.
      IF sy-subrc NE 0.
        es_error_occurred = abap_true.
      ENDIF.
    ENDIF.

*-----------------------------------------------------------------------
* assign attachments   !!!!!!!!!!!!!!!!! Implementação futura
*-----------------------------------------------------------------------
*
*    IF it_appcs IS SUPPLIED.
*      cl_ai_crm_im_sap_exch_ws_api=>conv_att2crm(
*        EXPORTING
*          it_appcs   = it_appcs
*        IMPORTING
*          et_crm_att = lt_crm_att
*      ).
*    ELSE.
*      CALL METHOD cl_ai_crm_im_sap_exch_api=>conv_att2crm
*        EXPORTING
*          it_appx_header         = it_appx_header
*          it_appx_data           = it_appx_data
*          it_appx_data_bin       = it_appx_data_bin
*        IMPORTING
*          et_crm_att             = lt_crm_att
*        EXCEPTIONS
*          local_ict_update_error = 1.
*    ENDIF.
*
*    IF sy-subrc <> 0.
*      CLEAR ls_msg.
*      es_error_occurred = abap_true.
*      MOVE-CORRESPONDING sy TO ls_msg.
*      APPEND ls_msg TO lt_msg.
*    ENDIF.
*
*    LOOP AT lt_crm_att ASSIGNING FIELD-SYMBOL(<fs_crm_att>).
*      CALL METHOD lr_1o_sd->add_attachment
*        EXPORTING
*          iv_doc_content  = <fs_crm_att>-doc_content
*          iv_file_name    = <fs_crm_att>-file_name
*          iv_content_type = <fs_crm_att>-content_type
*          iv_description  = <fs_crm_att>-description
*        EXCEPTIONS
*          OTHERS          = 1.
*      IF sy-subrc NE 0.
*        CLEAR ls_msg.
*        es_error_occurred = abap_true.
*        MOVE-CORRESPONDING sy TO ls_msg.
*        APPEND ls_msg TO lt_msg.
*      ENDIF.
*    ENDLOOP.

*-----------------------------------------------------------------------
* set SAP notes
*-----------------------------------------------------------------------

    LOOP AT is_data_incident-sap_notes ASSIGNING FIELD-SYMBOL(<fs_sap_notes>).
      ls_notes-sap_note    = <fs_sap_notes>-sap_note.
*      ls_notes-short_descr = .
      ls_notes-spras       = sy-langu.
      ls_notes-mod_flag    = 'U'.
      APPEND ls_notes TO lt_notes.
    ENDLOOP.

    CALL METHOD lr_1o_sd->set_sap_notes
      EXPORTING
        it_sap_notes = lt_notes
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc NE 0.
      es_error_occurred = abap_true.
    ENDIF.

*-----------------------------------------------------------------------
* save order
*-----------------------------------------------------------------------
    IF es_error_occurred IS NOT INITIAL.
      EXIT.
    ENDIF.

    CALL METHOD lr_1o_sd->save
      EXPORTING
        iv_unlock        = abap_true
        iv_init          = abap_true
      IMPORTING
        et_saved_objects = lt_ret_objects
      CHANGING
        cv_log_handle    = lv_log_handle
      EXCEPTIONS
        error_occurred   = 1
        OTHERS           = 2.
    IF sy-subrc NE 0.
      es_error_occurred = abap_true.
      EXIT.
    ENDIF.

*-----------------------------------------------------------------------
* set export data
*-----------------------------------------------------------------------
    READ TABLE lt_ret_objects INTO es_id_created INDEX 1.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SOPHIE_INCIDENT->INCIDENT_QUERY
* +-------------------------------------------------------------------------------------------------+
* | [<-->] IS_QUERY_RET                   TYPE        ZRET_INC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD incident_query.
    me->init_query_mode( is_query_ret ).
    me->set_guid_query( ).

    IF me->gs_query-message IS INITIAL.
      is_query_ret-retbasic = me->query_basic( ).

      IF is_query_ret-incidentno IS NOT INITIAL.
        lr_1o_sd = NEW #( iv_header_guid  = VALUE #( gt_guid[ 1 ]-guid OPTIONAL )
                          iv_process_type = VALUE #( gt_guid[ 1 ]-process_type OPTIONAL )
                          iv_process_mode = gc_mode-display ).
        is_query_ret-retcreation = me->query_creation( ).
        is_query_ret-retattend   = me->query_attend( ).
        is_query_ret-retsla      = me->query_sla( ).
      ENDIF.
    ENDIF.

    is_query_ret-message = me->gs_query-message.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->INIT_QUERY_MODE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_QUERY                       TYPE        ZRET_INC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD init_query_mode.
    me->gs_query = is_query.

    IF gs_query-incidentno IS NOT INITIAL.
      gv_by_company = abap_true.
      gv_qmode = gc_query_mode-by_incident.

    ELSEIF gs_query-user_status <> space AND gs_query-proc_type <> space.
      gv_qmode = gc_query_mode-by_status.

    ELSEIF gs_query-post_date IS NOT INITIAL.
      gv_qmode = gc_query_mode-by_postdate.
      IF gs_query-post_date_end IS NOT INITIAL.
        gr_posting_date = VALUE #( ( sign = 'I' option = 'BT' low = gs_query-post_date high = gs_query-post_date_end ) ).
      ELSE.
        gr_posting_date = VALUE #( ( sign = 'I' option = 'EQ' low = gs_query-post_date ) ).
      ENDIF.

    ELSEIF gs_query-description IS NOT INITIAL.
      gv_by_company = abap_true.
      gv_qmode = gc_query_mode-by_descr.
      gr_description = VALUE #( ( sign = 'I' option = 'CP' low = |*{ gs_query-description }*| )
                                ( sign = 'I' option = 'CP' low = |*{ gs_query-description(1) CASE = UPPER }{ gs_query-description+1 CASE = LOWER }*| )
                                ( sign = 'I' option = 'CP' low = |*{ gs_query-description CASE = UPPER }*| )
                                ( sign = 'I' option = 'CP' low = |*{ gs_query-description CASE = LOWER }*| ) ).

    ELSEIF gs_query-percent_mtp IS NOT INITIAL AND gs_query-proc_type <> space.
      gv_by_company = abap_true.
      gv_qmode = gc_query_mode-by_mtpperc.

    ELSEIF gs_query-cat_id <> space AND gs_query-proc_type <> space.
      gv_qmode = gc_query_mode-by_catid.

    ELSEIF gs_query-user_id <> space AND gs_query-proc_type <> space.                       "must be last
      gv_by_company = abap_true.
      gv_qmode = gc_query_mode-by_proctype.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->QUERY_ATTEND
* +-------------------------------------------------------------------------------------------------+
* | [<-()] ES_ATTEND                      TYPE        ZRET_ATTEND
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD query_attend.
    DATA lt_crm_text TYPE comt_text_textdata_t.

    lr_1o_sd->get_texts( IMPORTING et_text_all = lt_crm_text ).

    SORT lt_crm_text BY stxh-tdfdate stxh-tdftime DESCENDING.
    DELETE lt_crm_text WHERE stxh-tdid = 'SUSD'.

    DATA(lt_lines) = VALUE #( lt_crm_text[ 1 ]-lines OPTIONAL ).

    es_attend-last_note = REDUCE tdline( INIT lv_text TYPE tdline
                                          FOR ls_line IN lt_lines NEXT lv_text = |{ lv_text }\n{ ls_line-tdline }| ).
    REPLACE FIRST OCCURRENCE OF REGEX '\n' IN es_attend-last_note WITH ''.

    lr_1o_sd->get_subject( IMPORTING es_subject = DATA(ls_subject) ).

    cl_crm_ml_category_util=>get_cat_kids_all(
      EXPORTING
        iv_asp_id   = ls_subject-asp_id
        iv_cat_id   = ls_subject-cat_id
      IMPORTING
        et_cat      = DATA(lt_cat) ).

    IF lt_cat IS NOT INITIAL.
      cl_crm_ml_category_util=>get_selected_category_tree(
        EXPORTING
          iv_selected_cat_guid = lt_cat[ 1 ]-cat-cat_guid
          iv_schema_guid       = lt_cat[ 1 ]-cat-asp_guid
        IMPORTING
          et_cat_tree          = DATA(lt_tree) ).

      DELETE lt_tree WHERE key IS INITIAL.
      es_attend-category       = REDUCE #( INIT lv_value TYPE string
                                            FOR ls_tree IN lt_tree NEXT lv_value = |{ lv_value } -> { ls_tree-value }| ) .
    ENDIF.
    es_attend-partner_no_sup = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-support )-partner.
    es_attend-supname        = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-support )-name.
    es_attend-agentid        = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-processor )-partner.
    es_attend-agentename     = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-processor )-name.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->QUERY_BASIC
* +-------------------------------------------------------------------------------------------------+
* | [<-()] ET_QUERY_BASIC                 TYPE        ZTRET_BASIC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD query_basic.
    DATA: ls_query_basic TYPE LINE OF ztret_basic.

    SELECT priority, txt_long
      FROM scpriot
      INTO TABLE @DATA(lt_priority)
     WHERE langu = @sy-langu.

    LOOP AT gt_guid INTO DATA(ls_guid).
      lr_1o_sd = NEW #( iv_header_guid  = ls_guid-guid
                        iv_process_type = ls_guid-process_type
                        iv_process_mode = gc_mode-display ).

      ls_query_basic-incident_no = lr_1o_sd->av_object_id.
      lr_1o_sd->get_short_text( IMPORTING ev_short_text =  ls_query_basic-short_text ).
      lr_1o_sd->get_status( IMPORTING ev_user_status = DATA(lv_ustatus) et_status = DATA(lt_status) ).
      lr_1o_sd->get_priority( IMPORTING ev_priority = DATA(lv_priority) ).

      ls_query_basic-statustxt = |{ lv_ustatus } { VALUE #( lt_status[ status = lv_ustatus ]-txt30 OPTIONAL ) }|.
      ls_query_basic-priority = VALUE #( lt_priority[ priority = lv_priority ]-txt_long OPTIONAL ).

      IF gv_qmode = gc_query_mode-by_mtpperc.
        ls_query_basic-mpt_perc = lr_1o_sd->get_sla_status( )-mpt_perc.
      ENDIF.

      IF me->filter_query( ls_query_basic ) = abap_true.
        APPEND ls_query_basic TO et_query_basic.
      ENDIF.
      CLEAR: lr_1o_sd, ls_query_basic.
    ENDLOOP.
    IF et_query_basic IS INITIAL.
      me->gs_query-message = text-e03.
    ENDIF.
    SORT et_query_basic BY incident_no.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->QUERY_CREATION
* +-------------------------------------------------------------------------------------------------+
* | [<-()] ES_CREATION                    TYPE        ZRET_CREATION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD query_creation.
    lr_1o_sd->get_orderadm_h( IMPORTING es_orderadm_h =  DATA(ls_orderadm) ).

    es_creation-created_at = lr_1o_sd->convert_timestamp( ls_orderadm-created_at ).
    es_creation-created_by = ls_orderadm-created_by.
    es_creation-partner_no = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-notifier )-partner.
    es_creation-notifname  = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-notifier )-name.
    es_creation-partner_no_iss = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-issuer )-partner.
    es_creation-issuername = lr_1o_sd->get_partner_by_function( iv_partner_fct = gc_pfct-issuer )-name.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->QUERY_SLA
* +-------------------------------------------------------------------------------------------------+
* | [<-()] ES_SLA                         TYPE        ZRET_SLA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD query_sla.
    es_sla-proc_type    = lr_1o_sd->av_process_type.
    es_sla-mpt_duedate  = |{ lr_1o_sd->get_sla_status( )-mpt_timestamp TIMEZONE = '' }|. "lr_1o_sd->convert_timestamp( lr_1o_sd->get_sla_status( )-mpt_timestamp ).
    es_sla-mpt_perc     = lr_1o_sd->get_sla_status( )-mpt_perc.
    es_sla-mpt_status   = lr_1o_sd->get_sla_status( )-mpt_status_text.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_SOPHIE_INCIDENT->SET_GUID_QUERY
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD set_guid_query.
    IF gs_query-incidentno IS NOT INITIAL.

      DATA(lt_link) = me->get_partner_guid( iv_user = gs_query-user_id ).

      SELECT guid, process_type
        FROM crmd_orderadm_h
        INTO TABLE @gt_guid
         FOR ALL ENTRIES IN @lt_link
       WHERE guid = @lt_link-guid_hi
         AND object_id = @gs_query-incidentno.
    ELSE.
      IF gs_query-proc_type IS NOT INITIAL.
        gr_proc_type = VALUE #( ( sign = 'I' option = 'EQ' low = gs_query-proc_type ) ).
      ENDIF.

      lt_link = me->get_partner_guid( iv_user = gs_query-user_id ).

      SELECT guid, process_type
        FROM crmd_orderadm_h
        INTO TABLE @gt_guid
         FOR ALL ENTRIES IN @lt_link
       WHERE guid = @lt_link-guid_hi
         AND process_type IN @gr_proc_type
         AND posting_date IN @gr_posting_date
         AND description  IN @gr_description.
    ENDIF.
    IF sy-subrc <> 0.
      me->gs_query-message = text-e03.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
