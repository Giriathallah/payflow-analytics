import sys
import os
import json

from superset.app import create_app
app = create_app()

with app.app_context():
    from superset.extensions import db
    from superset.models.core import Database
    from superset.connectors.sqla.models import SqlaTable
    from superset.models.dashboard import Dashboard
    from superset.models.slice import Slice

    print("[INFO] Setting up ClickHouse Database Connection in Superset...")
    
    # 1. Register Database Connection
    db_name = "PayFlow ClickHouse Mart"
    sqlalchemy_uri = (
        "clickhousedb://{user}:{password}@{host}:{port}/{database}".format(
            user=os.environ.get("CLICKHOUSE_SUPERSET_USER", "superset_reader"),
            password=os.environ["CLICKHOUSE_SUPERSET_PASSWORD"],
            host=os.environ.get("CLICKHOUSE_HOST", "clickhouse"),
            port=os.environ.get("CLICKHOUSE_HTTP_PORT", "8123"),
            database=os.environ.get("CLICKHOUSE_DB_MART", "payflow_mart")
        )
    )
    
    database = db.session.query(Database).filter_by(database_name=db_name).first()
    if not database:
        database = Database(
            database_name=db_name,
            sqlalchemy_uri=sqlalchemy_uri,
            expose_in_sqllab=True,
            allow_run_async=False,
            allow_ctas=False,
            allow_cvas=False,
            allow_dml=False
        )
        db.session.add(database)
        db.session.commit()
        print(f"[SUCCESS] Database '{db_name}' registered successfully.")
    else:
        database.sqlalchemy_uri = sqlalchemy_uri
        database.allow_run_async = False
        db.session.commit()
        print(f"[INFO] Database '{db_name}' updated.")

    # 2. Register Datasets & Unconditionally Fetch Metadata (Columns)
    tables_config = {
        "mart_payment_performance": ("payflow_mart", "Hourly Payment Performance Mart"),
        "mart_failure_analysis": ("payflow_mart", "Failure Analysis Mart"),
        "mart_payment_funnel": ("payflow_mart", "Payment Funnel Mart"),
        "mart_merchant_daily_performance": ("payflow_mart", "Merchant Daily Performance Mart"),
        "mart_settlement_reconciliation": ("payflow_mart", "Settlement Reconciliation Mart"),
    }

    dataset_objects = {}

    for table_name, (schema_name, description) in tables_config.items():
        sqla_table = db.session.query(SqlaTable).filter_by(
            database_id=database.id,
            table_name=table_name,
            schema=schema_name
        ).first()
        if not sqla_table:
            sqla_table = SqlaTable(
                table_name=table_name,
                schema=schema_name,
                database=database,
                description=description
            )
            db.session.add(sqla_table)
            db.session.commit()
            print(f"[SUCCESS] Dataset '{table_name}' created.")
        else:
            print(f"[INFO] Dataset '{table_name}' found. Refreshing metadata...")
        
        try:
            sqla_table.fetch_metadata()
            db.session.commit()
            col_count = len(sqla_table.columns) if sqla_table.columns else 0
            print(f"[SUCCESS] Metadata for '{table_name}' fetched ({col_count} columns found).")
        except Exception as e:
            print(f"[WARN] fetch_metadata notice for {table_name}: {e}")
            
        dataset_objects[table_name] = sqla_table

    # Helper function to create or get Slice (Chart)
    def create_or_get_slice(slice_name, viz_type, dataset, params_dict):
        slc = db.session.query(Slice).filter_by(
            slice_name=slice_name,
            datasource_id=dataset.id,
            datasource_type='table'
        ).first()
        params_str = json.dumps(params_dict)
        if not slc:
            slc = Slice(
                slice_name=slice_name,
                viz_type=viz_type,
                datasource_type='table',
                datasource_id=dataset.id,
                params=params_str
            )
            db.session.add(slc)
            db.session.commit()
            print(f"  [+] Chart created: {slice_name}")
        else:
            slc.params = params_str
            slc.viz_type = viz_type
            db.session.commit()
            print(f"  [~] Chart updated: {slice_name}")
        return slc

    # Helper function to generate position_json grid layout for dashboard
    def build_position_json(slice_list):
        position = {
            "DASHBOARD_VERSION_KEY": "v2",
            "ROOT_ID": {
                "children": ["GRID_ID"],
                "id": "ROOT_ID",
                "type": "ROOT"
            },
            "GRID_ID": {
                "children": [],
                "id": "GRID_ID",
                "parents": ["ROOT_ID"],
                "type": "GRID"
            },
            "HEADER_ID": {
                "id": "HEADER_ID",
                "meta": {"text": ""},
                "type": "HEADER"
            }
        }

        row_idx = 0
        col_width = 6
        current_row_id = f"ROW-{row_idx}"
        current_row_children = []

        for idx, slc in enumerate(slice_list):
            chart_key = f"CHART-{slc.id}"
            position[chart_key] = {
                "children": [],
                "id": chart_key,
                "meta": {
                    "chartId": slc.id,
                    "height": 50,
                    "sliceName": slc.slice_name,
                    "width": col_width
                },
                "parents": ["ROOT_ID", "GRID_ID", current_row_id],
                "type": "CHART"
            }
            current_row_children.append(chart_key)

            if len(current_row_children) == 2 or idx == len(slice_list) - 1:
                position[current_row_id] = {
                    "children": current_row_children,
                    "id": current_row_id,
                    "meta": {"background": "BACKGROUND_TRANSPARENT"},
                    "parents": ["ROOT_ID", "GRID_ID"],
                    "type": "ROW"
                }
                position["GRID_ID"]["children"].append(current_row_id)
                row_idx += 1
                current_row_id = f"ROW-{row_idx}"
                current_row_children = []

        return json.dumps(position)

    # 3. Build Charts (Slices) for Dashboard 1: Executive Overview
    print("[INFO] Creating charts for Dashboard 1: Executive Overview...")
    d1_table_perf = dataset_objects["mart_payment_performance"]
    d1_table_merch = dataset_objects["mart_merchant_daily_performance"]

    s_exec_vol = create_or_get_slice(
        "Total Payment Volume (IDR)",
        "big_number_total",
        d1_table_perf,
        {
            "viz_type": "big_number_total",
            "datasource": f"{d1_table_perf.id}__table",
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(gross_amount)", "label": "Total Volume (IDR)"},
            "subheader": "Gross Payment Volume"
        }
    )

    s_exec_tx = create_or_get_slice(
        "Total Transactions Count",
        "big_number_total",
        d1_table_perf,
        {
            "viz_type": "big_number_total",
            "datasource": f"{d1_table_perf.id}__table",
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(transaction_count)", "label": "Transactions"},
            "subheader": "Total Ingested Transactions"
        }
    )

    s_exec_sr = create_or_get_slice(
        "Overall Success Rate (%)",
        "big_number_total",
        d1_table_perf,
        {
            "viz_type": "big_number_total",
            "datasource": f"{d1_table_perf.id}__table",
            "metric": {"expressionType": "SQL", "sqlExpression": "round(sum(success_count)/sum(transaction_count)*100, 2)", "label": "Success Rate (%)"},
            "subheader": "Authorization & Capture Success Rate"
        }
    )

    s_exec_fee = create_or_get_slice(
        "Total Fee Revenue (IDR)",
        "big_number_total",
        d1_table_merch,
        {
            "viz_type": "big_number_total",
            "datasource": f"{d1_table_merch.id}__table",
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(fee_amount)", "label": "Fee Revenue (IDR)"},
            "subheader": "Merchant Fee Earnings"
        }
    )

    s_exec_net = create_or_get_slice(
        "Net Settlement (IDR)",
        "big_number_total",
        d1_table_merch,
        {
            "viz_type": "big_number_total",
            "datasource": f"{d1_table_merch.id}__table",
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(net_settlement)", "label": "Net Settlement (IDR)"},
            "subheader": "Disbursed Net Amount"
        }
    )

    s_exec_trend = create_or_get_slice(
        "Daily Transaction Volume & Count Trend",
        "echarts_timeseries_line",
        d1_table_merch,
        {
            "viz_type": "echarts_timeseries_line",
            "datasource": f"{d1_table_merch.id}__table",
            "x_axis": "date",
            "metrics": [
                {"expressionType": "SQL", "sqlExpression": "sum(gross_amount)", "label": "Gross Volume (IDR)"},
                {"expressionType": "SQL", "sqlExpression": "sum(transaction_count)", "label": "Transaction Count"}
            ]
        }
    )

    # 4. Build Charts for Dashboard 2: Payment Operations
    print("[INFO] Creating charts for Dashboard 2: Payment Operations...")
    d2_table_perf = dataset_objects["mart_payment_performance"]
    d2_table_funnel = dataset_objects["mart_payment_funnel"]
    d2_table_fail = dataset_objects["mart_failure_analysis"]

    s_ops_hourly = create_or_get_slice(
        "Hourly Transaction Load (TPH)",
        "echarts_timeseries_line",
        d2_table_perf,
        {
            "viz_type": "echarts_timeseries_line",
            "datasource": f"{d2_table_perf.id}__table",
            "x_axis": "hour",
            "metrics": [{"expressionType": "SQL", "sqlExpression": "sum(transaction_count)", "label": "Transactions Count"}]
        }
    )

    s_ops_funnel = create_or_get_slice(
        "Payment Lifecycle Funnel",
        "table",
        d2_table_funnel,
        {
            "viz_type": "table",
            "datasource": f"{d2_table_funnel.id}__table",
            "groupby": ["date"],
            "metrics": [
                {"expressionType": "SQL", "sqlExpression": "sum(initiated_count)", "label": "Initiated"},
                {"expressionType": "SQL", "sqlExpression": "sum(authorized_count)", "label": "Authorized"},
                {"expressionType": "SQL", "sqlExpression": "sum(captured_count)", "label": "Captured"},
                {"expressionType": "SQL", "sqlExpression": "sum(settled_count)", "label": "Settled"},
                {"expressionType": "SQL", "sqlExpression": "sum(failed_count)", "label": "Failed"}
            ]
        }
    )

    s_ops_failure = create_or_get_slice(
        "Failure Reasons Breakdown",
        "pie",
        d2_table_fail,
        {
            "viz_type": "pie",
            "datasource": f"{d2_table_fail.id}__table",
            "groupby": ["failure_reason"],
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(failure_count)", "label": "Failures"}
        }
    )

    s_ops_method = create_or_get_slice(
        "Payment Method Distribution",
        "pie",
        d2_table_perf,
        {
            "viz_type": "pie",
            "datasource": f"{d2_table_perf.id}__table",
            "groupby": ["payment_method"],
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(gross_amount)", "label": "Gross Volume"}
        }
    )

    s_ops_provider = create_or_get_slice(
        "Payment Provider Volume",
        "pie",
        d2_table_perf,
        {
            "viz_type": "pie",
            "datasource": f"{d2_table_perf.id}__table",
            "groupby": ["provider"],
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(gross_amount)", "label": "Gross Volume"}
        }
    )

    # 5. Build Charts for Dashboard 3: Merchant Analytics
    print("[INFO] Creating charts for Dashboard 3: Merchant Analytics...")
    d3_table_merch = dataset_objects["mart_merchant_daily_performance"]

    s_merch_top = create_or_get_slice(
        "Top Merchants by Volume",
        "table",
        d3_table_merch,
        {
            "viz_type": "table",
            "datasource": f"{d3_table_merch.id}__table",
            "groupby": ["merchant_name"],
            "metrics": [
                {"expressionType": "SQL", "sqlExpression": "sum(gross_amount)", "label": "Total Volume (IDR)"},
                {"expressionType": "SQL", "sqlExpression": "sum(transaction_count)", "label": "Transaction Count"}
            ],
            "order_desc": True
        }
    )

    s_merch_sr = create_or_get_slice(
        "Merchant Success Rate Comparison",
        "table",
        d3_table_merch,
        {
            "viz_type": "table",
            "datasource": f"{d3_table_merch.id}__table",
            "groupby": ["merchant_name"],
            "metrics": [
                {"expressionType": "SQL", "sqlExpression": "round(sum(successful_transaction_count)/sum(transaction_count)*100, 2)", "label": "Success Rate (%)"}
            ],
            "order_desc": True
        }
    )

    s_merch_fee = create_or_get_slice(
        "Merchant Fee Contribution",
        "pie",
        d3_table_merch,
        {
            "viz_type": "pie",
            "datasource": f"{d3_table_merch.id}__table",
            "groupby": ["merchant_name"],
            "metric": {"expressionType": "SQL", "sqlExpression": "sum(fee_amount)", "label": "Fee Amount (IDR)"}
        }
    )

    s_merch_refund = create_or_get_slice(
        "Refund Rate per Merchant",
        "table",
        d3_table_merch,
        {
            "viz_type": "table",
            "datasource": f"{d3_table_merch.id}__table",
            "groupby": ["merchant_name"],
            "metrics": [
                {"expressionType": "SQL", "sqlExpression": "sum(refund_amount)", "label": "Refund Amount (IDR)"},
                {"expressionType": "SQL", "sqlExpression": "round(sum(refund_amount)/sum(gross_amount)*100, 2)", "label": "Refund Rate (%)"}
            ]
        }
    )

    # 6. Build Charts for Dashboard 4: Settlement Reconciliation
    print("[INFO] Creating charts for Dashboard 4: Settlement Reconciliation...")
    d4_table_recon = dataset_objects["mart_settlement_reconciliation"]

    s_recon_status = create_or_get_slice(
        "Reconciliation Status Breakdown",
        "pie",
        d4_table_recon,
        {
            "viz_type": "pie",
            "datasource": f"{d4_table_recon.id}__table",
            "groupby": ["reconciliation_status"],
            "metric": {"expressionType": "SQL", "sqlExpression": "count(batch_id)", "label": "Batch Count"}
        }
    )

    s_recon_expected_vs_actual = create_or_get_slice(
        "Expected vs Actual Net Settlement",
        "echarts_timeseries_line",
        d4_table_recon,
        {
            "viz_type": "echarts_timeseries_line",
            "datasource": f"{d4_table_recon.id}__table",
            "x_axis": "settlement_date",
            "metrics": [
                {"expressionType": "SQL", "sqlExpression": "sum(expected_amount)", "label": "Expected Amount"},
                {"expressionType": "SQL", "sqlExpression": "sum(actual_amount)", "label": "Actual Amount"},
                {"expressionType": "SQL", "sqlExpression": "sum(difference)", "label": "Difference"}
            ]
        }
    )

    s_recon_mismatch_table = create_or_get_slice(
        "Settlement Batch Reconciliation Detail",
        "table",
        d4_table_recon,
        {
            "viz_type": "table",
            "datasource": f"{d4_table_recon.id}__table",
            "groupby": ["settlement_date", "merchant_id", "batch_id", "reconciliation_status"],
            "metrics": [
                {"expressionType": "SQL", "sqlExpression": "sum(matched_count)", "label": "Matched Items"},
                {"expressionType": "SQL", "sqlExpression": "sum(mismatch_count)", "label": "Mismatch Items"},
                {"expressionType": "SQL", "sqlExpression": "sum(missing_count)", "label": "Missing Items"},
                {"expressionType": "SQL", "sqlExpression": "sum(duplicate_count)", "label": "Duplicate Items"},
                {"expressionType": "SQL", "sqlExpression": "sum(difference)", "label": "Discrepancy (IDR)"}
            ]
        }
    )

    # 7. Create Dashboards and Assign Slices with position_json
    dashboards_mapping = [
        (
            "Executive Overview",
            "executive-overview",
            [s_exec_vol, s_exec_tx, s_exec_sr, s_exec_fee, s_exec_net, s_exec_trend]
        ),
        (
            "Payment Operations",
            "payment-operations",
            [s_ops_hourly, s_ops_funnel, s_ops_failure, s_ops_method, s_ops_provider]
        ),
        (
            "Merchant Analytics",
            "merchant-analytics",
            [s_merch_top, s_merch_sr, s_merch_fee, s_merch_refund]
        ),
        (
            "Settlement Reconciliation",
            "settlement-reconciliation",
            [s_recon_status, s_recon_expected_vs_actual, s_recon_mismatch_table]
        )
    ]

    for title, slug, slice_list in dashboards_mapping:
        dash = db.session.query(Dashboard).filter_by(slug=slug).first()
        if not dash:
            dash = Dashboard(
                dashboard_title=title,
                slug=slug,
                published=True
            )
            db.session.add(dash)
            db.session.commit()
            print(f"[SUCCESS] Dashboard '{title}' created.")
        
        dash.published = True
        dash.slices = slice_list
        dash.position_json = build_position_json(slice_list)
        db.session.commit()
        print(f"[SUCCESS] Dashboard '{title}' linked with {len(slice_list)} charts & position grid updated.")

    print("[SUCCESS] All Superset Charts, Datasets, and Dashboards initialized successfully.")
