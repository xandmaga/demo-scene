#!/bin/sh

echo 'Creating Debezium tables'

sqlplus Debezium/dbz@//localhost:1521/ORCLPDB1  <<- EOF

drop table PE_TB_PROCESSO_PARTE purge;
drop table PE_TB_PROCESSO_TRF purge;
drop table PE_TB_USUARIO_LOGIN purge;
  
create table PE_TB_PROCESSO_TRF
(
	ID_PROCESSO_TRF NUMBER(10) not null
		constraint PK_PTRF
			primary key,
	NR_SEQUENCIA NUMBER(7),
	NR_DIGITO_VERIFICADOR NUMBER(2),
	NR_ANO NUMBER(4),
	NR_IDENTIFICACAO_ORGAO_JUSTICA NUMBER(3),
	CD_PROCESSO_STATUS CHAR
		constraint CK_PTRF_CD_PROCESSO_STATUS
			check (cd_processo_status IN ('E', 'V', 'D'))
);



create table PE_TB_USUARIO_LOGIN
(
	ID_USUARIO NUMBER(10) not null
		constraint PK_USLG
			primary key,
	DS_EMAIL VARCHAR2(100),
	DS_LOGIN VARCHAR2(100) not null
		constraint UK_USLG02
			unique,
	DS_NOME VARCHAR2(255) not null,
	DS_SENHA VARCHAR2(100),
	IN_ATIVO VARCHAR2(5),
	DS_ASSINATURA_USUARIO CLOB,
	DS_CERT_CHAIN_USUARIO CLOB,
	ID_PK_TB_USUARIO_LOGIN_PG NUMBER(10),
	ID_SESSAO_PG NUMBER(10),
	HASH_ATIVACAO_SENHA VARCHAR2(255),
	IN_STATUS_SENHA CHAR default 'I' not null,
	DT_VALIDADE_SENHA DATE,
	DATA_INCLUSAO_ODS DATE,
	DATA_ATUALIZACAO_ODS DATE,
	constraint UK_USLG01
		unique (ID_SESSAO_PG, ID_PK_TB_USUARIO_LOGIN_PG)
);


create table PE_TB_PROCESSO_PARTE
(
	ID_PROCESSO_PARTE NUMBER(10) not null
		constraint PK_PRPT
			primary key,
	ID_PROCESSO_TRF NUMBER(10) not null
		constraint FK_PRPT_PTRF04
			references PE_TB_PROCESSO_TRF
				on delete cascade,
	ID_PESSOA NUMBER(10) not null
		constraint FK_PRPT_PSSO01
			references PE_TB_USUARIO_LOGIN
);

EOF

sqlplus sys/top_secret@//localhost:1521/ORCLPDB1 as sysdba <<- EOF

  ALTER TABLE debezium.PE_TB_PROCESSO_TRF ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
  GRANT SELECT ON debezium.PE_TB_PROCESSO_TRF to c##dbzuser;

  ALTER TABLE debezium.PE_TB_USUARIO_LOGIN ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
  GRANT SELECT ON debezium.PE_TB_USUARIO_LOGIN to c##dbzuser;

  ALTER TABLE debezium.PE_TB_PROCESSO_PARTE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
  GRANT SELECT ON debezium.PE_TB_PROCESSO_PARTE to c##dbzuser;  

  -- From https://xanpires.wordpress.com/2013/06/26/how-to-check-the-supplemental-log-information-in-oracle/
  COLUMN LOG_GROUP_NAME HEADING 'Log Group' FORMAT A20
  COLUMN TABLE_NAME HEADING 'Table' FORMAT A20
  COLUMN ALWAYS HEADING 'Type of Log Group' FORMAT A30

  SELECT LOG_GROUP_NAME, TABLE_NAME, DECODE(ALWAYS, 'ALWAYS', 'Unconditional', NULL, 'Conditional') ALWAYS FROM DBA_LOG_GROUPS;

  exit;
EOF
