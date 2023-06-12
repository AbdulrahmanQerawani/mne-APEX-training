-- PL/SQL Call :
DECLARE
V_USER_ID  VARCHAR2(100) := APEX_UTIL.GET_CURRENT_USER_ID;
  --&P3_REFER_LICENSE_ID.
BEGIN

    OPENKM_INTEGRATION_PKG.CREATE_FOLDER_IN_OPENKM
( p_author          => V_USER_ID,
      p_categories      => :P3_APP_TYPE,
      p_keywords        => :P3_APP_ID,
      p_notes           => 'This Folder contains attached files for organization no'||:P3_ORGANIZATION_ID,
      p_organization_id => :P3_ORGANIZATION_ID
     );

    OPENKM_INTEGRATION_PKG.CREATE_FILE_IN_OPENKM
( p_fileName        => :P3_APP_FILE,
      p_organization_id => :P3_ORGANIZATION_ID,
      p_app_id          => :P3_APP_ID,
      p_author          => V_USER_ID,
      p_title           => 'replacement license application no.'||:P3_APP_ID,
      p_description     => 'This replacenment license application after manager assign and stamp'
     );
EXCEPTION
    WHEN OTHERS THEN
    RAISE;
END;
-------------------------------------------------------------------------------------------------------------
-- OpenKM Integration Package : OPENKM_INTEGRATION_PKG
-------------------------------------------------------------------------------------------------------------
create or replace PACKAGE openkm_integration_pkg
  IS
    l_filename     VARCHAR2(255);
    l_filetype     VARCHAR2(255);
    l_BLOB         BLOB;
    l_CLOB         CLOB;
    l_response     CLOB;
    l_msg_response VARCHAR2(4000);
    l_envelope     CLOB;
    l_xml          XMLTYPE;
    l_token        VARCHAR2(4000);
    l_base_path    VARCHAR2(100) := '/okm:root/apex/2023/إجراء اصدار شهادة بدل فاقد/';
    l_is_created   VARCHAR2(100);
    l_services_url VARCHAR2(4000) := 'http://192.0.0.114:8080/OpenKM/services/';
    l_folder_name  VARCHAR2(4000);
    l_fault_error  VARCHAR2(4000);
   PROCEDURE upload_multiple_files
    ( p_doc IN VARCHAR2,
      p_organization_id IN NUMBER,
      p_app_id IN NUMBER);

   PROCEDURE upload_single_file
    ( p_doc IN VARCHAR2,
      p_organization_id IN NUMBER,
      p_app_id IN NUMBER);

   FUNCTION get_openkm_token
    ( p_username IN VARCHAR2,
      p_password IN VARCHAR2) RETURN VARCHAR2;

    PROCEDURE CREATE_FOLDER_IN_OPENKM
    ( p_author          IN VARCHAR2,
      p_categories      IN VARCHAR2,
      p_keywords        IN VARCHAR2,
      p_notes           IN VARCHAR2,
      p_organization_id IN VARCHAR2
     );

    PROCEDURE CREATE_FILE_IN_OPENKM
    ( p_fileName        IN VARCHAR2,
      p_organization_id IN VARCHAR2,
      p_app_id          IN VARCHAR2,
      p_author          IN VARCHAR2,
      p_title           IN VARCHAR2,
      p_description     IN VARCHAR2
     );
END;



create or replace PACKAGE BODY openkm_integration_pkg
IS

   PROCEDURE upload_multiple_files
    ( p_doc IN VARCHAR2,
      p_organization_id IN NUMBER,
      p_app_id IN NUMBER)
    IS
    l_file_names apex_t_varchar2;
    l_file apex_application_temp_files%rowtype;

BEGIN
    l_file_names := apex_string.split (
    p_str => p_doc,
    p_sep => ':' );

for i in 1 .. l_file_names.count loop
select *
into l_file
from apex_application_temp_files
where name = l_file_names(i);

insert into mne_license_files (organization_id, app_id, name, FILENAME , MIME_TYPE , CREATED_ON , BLOB_CONTENT )
values (to_number(p_organization_id) , to_number(p_app_id), l_file.name, l_file.filename , l_file.mime_type , l_file.created_on , l_file.blob_content);
end loop;

EXCEPTION
      WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20001,'ERROR OCCUR WHILE UPLOADING MULTIPLE FILES') ;
END;

   PROCEDURE upload_single_file
    ( p_doc IN VARCHAR2,
      p_organization_id IN NUMBER,
      p_app_id IN NUMBER)
IS
BEGIN
FOR C1 IN (SELECT *
        FROM APEX_APPLICATION_TEMP_FILES
        WHERE NAME = p_doc)
        LOOP
            insert into mne_license_files (organization_id, app_id, name, FILENAME , MIME_TYPE , CREATED_ON , BLOB_CONTENT )
            values (p_organization_id , p_app_id, C1.name, C1.filename , C1.mime_type , C1.created_on , C1.blob_content);
END LOOP;

EXCEPTION
      WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20002,'ERROR OCCUR WHILE UPLOADING SINGLE FILE') ;
END;
   --
   FUNCTION is_folder_exists return boolean
   is
BEGIN
       -- Validate the folder created .
       l_envelope := '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://ws.openkm.com">
      <soap:Body>
        <tns:isValid>
            <token>'||l_token||'</token>
            <fldPath>'||l_folder_name||'</fldPath>
        </tns:isValid>
      </soap:Body>
    </soap:Envelope>';
      /*  dbms_output.put_line('start validate  l_envelope=
        '||l_envelope);*/
        l_xml := apex_web_service.make_request(
           p_url               => l_services_url||'OKMFolder',
           p_action            => 'http://ws.openkm.com/isValid',
           p_envelope          => l_envelope
           );

SELECT l_xml.extract('//ns2:isValidResponse/return/text()', 'xmlns:ns2="http://ws.openkm.com"').getStringVal()
INTO l_is_created
FROM dual;
dbms_output.put_line('l_is_created='||l_is_created);

        if (l_is_created = 'true')
        then
            dbms_output.put_line('folder is created successfully.');
return true;
end if;

return false;

EXCEPTION
    when OTHERS then
       RAISE_APPLICATION_ERROR(-20003,'error iccur while checking file exists in openkm., ');
END;

------------------------------------------------------------------------------------------------------------------
   FUNCTION get_openkm_token
    ( p_username IN VARCHAR2,
      p_password IN VARCHAR2) RETURN VARCHAR2
    IS
    l_response     CLOB;
    l_services_url VARCHAR2(4000) := 'http://192.0.0.114:8080/OpenKM/services/';
    l_xml          XMLTYPE;
    l_token        VARCHAR2(4000);
BEGIN
        apex_web_service.g_request_headers.delete; -- Clear request headers

        l_response := apex_web_service.make_rest_request(
            p_url => l_services_url||'OKMAuth/login',
            p_http_method => 'GET',
            p_parm_name => apex_util.string_to_table('user:password'), -- Query parameter names
            p_parm_value => apex_util.string_to_table('okmAdmin:Just_4_OpenKM') -- Query parameter values
        );

        -- Print the XML response for debugging
       /* dbms_output.put_line('l_response='||l_response||'
        --------------------------------------------------');*/

        -- Check if l_response contains valid XML data
BEGIN
            l_xml := XMLTYPE(l_response);
EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20004,'Error parsing XML: '||SQLERRM);
END;

        -- Extract the value from the XML data
BEGIN
SELECT l_xml.EXTRACT('/soap:Envelope/soap:Body/ns2:loginResponse/return/text()',
                     'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:ns2="http://ws.openkm.com"').GETSTRINGVAL()
INTO l_token
FROM dual;
dbms_output.put_line('l_token='||l_token||'
            -------------------------------------------');
            l_response := NULL;
            l_xml      := NULL;
EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20005,'Error while extracting token from XML: '||SQLERRM);
END;
RETURN l_token;
END;

    PROCEDURE CREATE_FOLDER_IN_OPENKM
    ( p_author          IN VARCHAR2,
      p_categories      IN VARCHAR2,
      p_keywords        IN VARCHAR2,
      p_notes           IN VARCHAR2,
      p_organization_id IN VARCHAR2
     )
IS
      v_org_name varchar2(100);
BEGIN

        -- Call OpenKM API to get login token.
        l_token := get_openkm_token( p_username => 'okmAdmin',p_password => 'Just_4_OpenKM');

select org_a_name into v_org_name from organization where id = p_organization_id;

l_folder_name := l_base_path||v_org_name;

        l_envelope := '';

        -- Check if folder is exists do nothing.
        IF (not is_folder_exists)
        THEN

               --  Call soap service to create folder.
               -- l_envelope := q'!<?xml version='1.0' encoding='UTF-8'?>!';
               l_envelope := '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://ws.openkm.com">
              <soap:Body>
                <tns:create>
                    <token>'||l_token||'</token>
                    <fld>
                        <author>'||p_author||'</author>
                        <categories>'||p_categories||'</categories>
                        <created>'||TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')||'</created>
                        <keywords>'||p_keywords||'</keywords>
                        <notes>'||p_notes||'</notes>
                        <path>'||l_folder_name||'</path>
                        <permissions>700</permissions>
                        <subscribed>false</subscribed>
                        <subscriptors></subscriptors>
                        <hasChildren>false</hasChildren>
                    </fld>
                </tns:create>
              </soap:Body>
            </soap:Envelope>';
           /* dbms_output.put_line('start create folder url:'||l_services_url||'OKMFolder'||' l_envelope=
            '||l_envelope||'
            -------------------------------------------------------');*/
            l_xml := apex_web_service.make_request(
               p_url               =>  l_services_url||'OKMFolder',
               p_envelope          => l_envelope
               );

            --
BEGIN

            -- Extract faultstring from the XMLType object
SELECT EXTRACTVALUE(l_xml, '/soap:Envelope/soap:Body/soap:Fault/faultstring', 'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"')
INTO l_fault_error
FROM dual;

if l_fault_error is not null
                then
                    RAISE_APPLICATION_ERROR(-20006,'soap:Client Error: '||l_fault_error||' '||l_msg_response);
end if;

BEGIN

                DBMS_OUTPUT.PUT_LINE('xml content='||l_xml.getstringval());
                -- Extract RESPONSE from the XMLType object
SELECT EXTRACTVALUE(l_xml, '/soap:Envelope/soap:Body/ns2:createResponse/return/text()', 'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                          xmlns:ns2="http://ws.openkm.com"')
INTO l_msg_response
FROM dual;

dbms_output.put_line('debug l_msg_response='|| l_msg_response);
                if (l_msg_response = l_folder_name)
                then
                 dbms_output.put_line('folder created successfully in path:'||l_folder_name);
end if;
END;

END;
END IF;
        dbms_output.put_line('Folder Is Already Exists.');
EXCEPTION
    when OTHERS then
        RAISE_APPLICATION_ERROR(-20007,'Error Occur While Creating Folder in OpenKM, '||SQLERRM);
END CREATE_FOLDER_IN_OPENKM;
/**/

    PROCEDURE CREATE_FILE_IN_OPENKM
    ( p_fileName        IN VARCHAR2,
      p_organization_id IN VARCHAR2,
      p_app_id          IN VARCHAR2,
      p_author          IN VARCHAR2,
      p_title           IN VARCHAR2,
      p_description     IN VARCHAR2
     )
IS
     cursor c1 is (SELECT filename, BLOB_CONTENT, mime_type
                   FROM mne_license_files
                   WHERE organization_id = to_number(p_organization_id) and app_id = to_number(p_app_id));
BEGIN

      -- Save file to database.
        upload_multiple_files
(p_doc => p_fileName,
              p_organization_id => p_organization_id,
              p_app_id => p_app_id);

    -- Retern savied file.
for r1 in c1 loop
            l_filename := r1.filename; l_BLOB := r1.BLOB_CONTENT; l_filetype := r1.mime_type;

            -- Convert file to clob.
            l_CLOB := apex_web_service.blob2clobbase64(l_BLOB);
            -- Call soap service to create file.
            l_envelope := '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://ws.openkm.com">
                  <soap:Body>
                    <tns:create>
                        <content>'||l_CLOB||'</content>
                        <token>'||l_token||'</token>
                        <doc>
                            <author>'||p_author||'</author>
                            <title>'||p_title||'</title>
                            <convertibleToPdf>true</convertibleToPdf>
                            <mimeType>'||l_filetype||'</mimeType>
                            <description>'||p_description||'</description>
                            <path>'||l_folder_name||'/'||l_filename||'</path>
                        </doc>
                    </tns:create>
                  </soap:Body>
                </soap:Envelope>';
                /*
                 l_envelope := l_envelope ||'<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://ws.openkm.com">
                  <soap:Body>
                    <tns:create>
                        <token>'||l_token||'</token>
                        <docPath>'||l_folder_name||'/'||l_filename||'</docPath>
                    </tns:create>
                  </soap:Body>
                </soap:Envelope>';   */


            l_xml := apex_web_service.make_request(
               p_url               => l_services_url||'OKMDocument',
               p_envelope          => l_envelope
               );

            -- Extract faultstring from the XMLType object
SELECT EXTRACTVALUE(l_xml, '/soap:Envelope/soap:Body/soap:Fault/faultstring', 'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"')
INTO l_fault_error
FROM dual;

if l_fault_error is not null
                then
                    if (INSTR(l_fault_error,l_filename)>0)
                    then
                    RAISE_APPLICATION_ERROR(-20008,'file is already archived and exists in openkm.');-- ,error:||l_fault_error||' l_folder_name='||l_folder_name
end if;
                    RAISE_APPLICATION_ERROR(-20008,'Error Occur while creating file: '||l_filename||' soap:Client Error is "'||l_fault_error||'"'||' '||l_msg_response);
                    exit;
end if;


            DBMS_OUTPUT.PUT_LINE('xml content='||l_xml.getstringval());
            -- Extract RESPONSE from the XMLType object
select l_xml.extract('//path/text()').getStringVal()
       -- SELECT EXTRACTVALUE(l_xml, '/soap:Envelope/soap:Body/ns2:createResponse/return/path/text()', 'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns2="http://ws.openkm.com"')
INTO l_msg_response
FROM dual;

if (INSTR(l_msg_response,l_filename)>0)
            then
                dbms_output.put_line('file is archived SUCCESSFULY in path:'||l_msg_response);
else
                RAISE_APPLICATION_ERROR(-20009,'Failed to Archive File In OpenKM Path:'||l_folder_name||l_filename||'.'||' l_msg_response='||l_msg_response||'the xml response content is:'||l_xml.getstringval());
                exit;
end if;
end loop;

        -- Clean
DELETE FROM mne_license_files
WHERE organization_id = to_number(p_organization_id) and app_id = to_number(p_app_id);

EXCEPTION
    WHEN OTHERS
    THEN
        RAISE_APPLICATION_ERROR(-20010,'Error Occur While Saving File to OpenKM, '||SQLERRM);

END CREATE_FILE_IN_OPENKM;
END;


