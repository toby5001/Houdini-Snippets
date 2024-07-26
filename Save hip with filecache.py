# This is intended to be used as a pre-render script with a file cache node, saving the current hipfile alongside the cached files
import os

org_file_name = hou.hipFile.path()
backup_file_name = hou.evalParm('../cachedir')+'/'+hou.hipFile.basename()
os.makedirs(os.path.dirname(backup_file_name), exist_ok=True)

hou.hipFile.save(file_name=backup_file_name, save_to_recent_files=False) 
hou.hipFile.setName(org_file_name) 