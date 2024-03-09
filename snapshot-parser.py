import os
import xlsxwriter
import argparse
import textwrap

path = "."

xlsx_filename = 'output-summary.xlsx'

def parse_args():
  parser = argparse.ArgumentParser( prog='snapshot-parser.py', description=textwrap.dedent("""
Parse Snapshots collected from the snapshot tool. 
  """),
  epilog=textwrap.dedent('''\
  Example:
  python3 snapshot-parser.py --Path /path/to/snapshots/'''))

  parser.add_argument(
    "--Path", 
    default=".",
    help=("Location of the base directory to search for snapshots.  Defaults to the current directory.")
  )

  parser.add_argument(
    "--OutputFile", 
    default=xlsx_filename,
    help=(f"Location of the base directory to search for snapshots.  Default is {xlsx_filename}")
  )

  arg = parser.parse_args()
  return arg


def write_df_header(workbook, sheet_name):
  xlsx_header = ['Snapshot', 'Size(G)', 'Used(G)', 'Avail(G)', 'Used%', 'FileSystem']

  worksheet = workbook.add_worksheet(sheet_name)
  col = 0
  for cell_data in xlsx_header:
    worksheet.write(0, col, cell_data)
    col += 1


def open_output_files():
  print(f"Creating excel output file: {xlsx_filename}")
  workbook  = xlsxwriter.Workbook(xlsx_filename)
  
  write_df_header(workbook, 'df-analytics')
  write_df_header(workbook, 'df-metrics')
  write_df_header(workbook, 'df-objects')
  write_df_header(workbook, 'df-data')
  write_df_header(workbook, 'df-rancher')

  print("\n")
  return workbook


def close_output_files(workbook):
  workbook.close()


def process_df(dir, workbook, row_id):
    normalized_dir =  os.path.basename(os.path.normpath(dir))
    dir_name = normalized_dir[9:]

    cell_percent = workbook.add_format()    
    cell_percent.set_num_format('0%')
    with open(os.path.join(dir, 'df.txt')) as f:
      for line in f:
        worksheet = None
        if "analytics" in line:
          split_line = line.split()
          #analytics_out.write(f"{dir_name}, {(split_line[1])[:-1]}, {(split_line[2])[:-1]}, {(split_line[3])[:-1]}, {split_line[4]}, {split_line[5]}\n")
          worksheet = workbook.get_worksheet_by_name('df-analytics')
        elif "metrics" in line:
          split_line = line.split()
          #metrics_out.write(f"{dir_name}, {(split_line[1])[:-1]}, {(split_line[2])[:-1]}, {(split_line[3])[:-1]}, {split_line[4]}, {split_line[5]}\n")
          worksheet = workbook.get_worksheet_by_name('df-metrics')
        elif "/mnt/instana/stanctl/objects" in line:
          split_line = line.split()
          #objects_out.write(f"{dir_name}, {(split_line[1])[:-1]}, {(split_line[2])[:-1]}, {(split_line[3])[:-1]}, {split_line[4]}, {split_line[5]}\n")
          worksheet = workbook.get_worksheet_by_name('df-objects')
        elif "/mnt/instana/stanctl/data" in line:
          split_line = line.split()
          #data_out.write(f"{dir_name}, {(split_line[1])[:-1]}, {(split_line[2])[:-1]}, {(split_line[3])[:-1]}, {split_line[4]}, {split_line[5]}\n")
          worksheet = workbook.get_worksheet_by_name('df-data')
        elif "/var/lib/rancher" in line:
          split_line = line.split()
          #rancher_out.write(f"{dir_name}, {(split_line[1])[:-1]}, {(split_line[2])[:-1]}, {(split_line[3])[:-1]}, {split_line[4]}, {split_line[5]}\n")
          worksheet = workbook.get_worksheet_by_name('df-rancher')
        if worksheet:
          worksheet.write(row_id,0, dir_name)
          worksheet.write_number(row_id,1, float((split_line[1])[:-1]))

          if (split_line[2].endswith('G')):
            worksheet.write_number(row_id,2, float((split_line[2])[:-1]))
          elif (split_line[2].endswith('M')):
            worksheet.write_number(row_id,2, float((split_line[2])[:-1])/1000)
          elif (split_line[2] == '0' ):
            worksheet.write_number(row_id,2, float(split_line[2]))

          if (split_line[3].endswith('G')):
            worksheet.write_number(row_id,3, float((split_line[3])[:-1]))
          elif (split_line[3].endswith('M')):
            worksheet.write_number(row_id,3, float((split_line[3])[:-1])/1000)
          elif (split_line[3] == '0' ):
            worksheet.write_number(row_id,3, float(split_line[3]))
          else:
            print(f"WARNING: Unable to parse value: {split_line[3]}")

          pct = float((split_line[4])[:-1]) * 0.01
          worksheet.write(row_id,4, pct, cell_percent)
          worksheet.write(row_id,5, split_line[5])


def add_chart(workbook, row_id, worksheet_name, chart_title):
  worksheet = workbook.get_worksheet_by_name(worksheet_name)
  chart = workbook.add_chart({'type': 'line'})

  chart.set_title({"name": chart_title})
  chart.set_y_axis({"name": "Storage in GB "})
  chart.set_size({'width': 920, 'height': 450})

  chart.add_series({"name": f"='{worksheet_name}'!$C$1",
                    "values": f"='{worksheet_name}'!$C$2:$C${row_id}"})

  chart.add_series({"name": f"='{worksheet_name}'!$B$1",
                    "values": f"='{worksheet_name}'!$B$2:$B${row_id}"})

  worksheet.insert_chart('J3', chart)


def add_charts(workbook, row_id):
  add_chart(workbook, row_id, 'df-analytics', 'Growth of Analytics Filesystem')
  add_chart(workbook, row_id, 'df-metrics', 'Growth of Metrics Filesystem')
  add_chart(workbook, row_id, 'df-objects', 'Growth of Objects Filesystem')
  add_chart(workbook, row_id, 'df-data', 'Growth of Data Filesystem')
  add_chart(workbook, row_id, 'df-rancher', 'Growth of Rancher Filesystem')

args = parse_args()

if path != args.Path:
   print("Updating Path...")
   path = args.Path

if xlsx_filename != args.OutputFile:
   print("Updating Output filename...")
   xlsx_filename = args.OutputFile


print(f"processing snapshots from the path: {path}")
snapshot_count = 0


workbook = open_output_files()

list_subfolders_with_paths = [f.path for f in os.scandir(path) if f.is_dir()]
list_subfolders_with_paths.sort()
for dir in list_subfolders_with_paths:
  normalized_dir =  os.path.basename(os.path.normpath(dir))
  # print(f"dir -> {dir} ({normalized_dir})")
  if normalized_dir.startswith('snapshot-'):
    snapshot_count += 1
    process_df(dir, workbook, snapshot_count)


add_charts(workbook, snapshot_count)

close_output_files(workbook)

print(f"Finished processing snapshots. Processed {snapshot_count} snapshots.")

