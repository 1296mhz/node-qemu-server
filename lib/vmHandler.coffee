exec = require('child_process').exec
fs   = require 'fs'
qemu = require './qemu'

config = require './config'

images       = {}
vms          = {}
isos         = []

createImage = (img, cb) ->
  qemu.createImage img, (ret) ->
    if      ret.status is 'success'
      images[img.name] = ret.data
      image.info (ret) ->  
        cb {status:'success', data:ret}      
    else if ret.status is 'error'
      cb status:'error'
      
deleteImage = (img, cb) ->
  if images[img.name]?
    images[img.name].delete (ret) ->
      cb ret
      if ret.status is 'success'
        delete images[img.name]

###
#   create VM
### 
module.exports.createVm = (vmCfg, cb) ->
  for vmName of vms
    if vmName is vmCfg.name
      cb status:'error', msg:"VM with the name '#{vmCfg.name}' already exists"
      return

  vmCfg.settings['qmpPort'] = config.getFreeQMPport()    
  if vmCfg.settings.vnc then vmCfg.settings.vnc = config.getFreeVNCport()

  obj = qemu.createVm vmCfg
  vms[vmCfg.name] = obj

  if vmCfg.settings.boot is true
    obj.start ->
      console.log "vm #{vmCfg.name} started"
      cb {status:'success', msg:'vm created and started'}

  cb {status:'success', msg:'created vm'}

###
#   read vmConfigs
###
readVmCfgs = ->
  exec "cd vmConfigs && ls -v *.json", (err, stdout, stderr) ->
    cfgs = stdout.split '\n'
    cfgs.pop()
    
    for cfg in cfgs
      cfg = JSON.parse fs.readFileSync "vmConfigs/#{cfg}"
      
      obj = qemu.createVm cfg
      console.log obj
      vms[cfg.name] = obj
      if cfg.settings.boot is true
        obj.start ->
          console.log "vm #{cfg.name} started"

###
#   read images
###
readImages = ->
  exec "cd images && ls -v *.img", (err, stdout, stderr) ->
    imgs = stdout.split '\n'
    imgs.pop()
  
    for img in imgs
      img = img.split('.')[0]
      images[img] = new qemu.Image img
      
    console.dir images

###
#   read isos
###
readIsos = ->
  exec "cd isos && ls -v *.iso", (e, stdout, stderr) ->
    ns = stdout.split '\n'
    ns.pop()
    isos.push iso for iso in ns


getIsos = ->
  return isos

getDisks = ->
  return images

getVms = ->
  return vms

module.exports.vmShutdown = (cfg, code, signal) ->
  console.log "VM #{cfg.name} shut down"

  if vms[cfg.name]?
    vm = vms[cfg.name]
    vm.deleteProcess()
    vm.deleteQmp()
    
    delete vms[cfg.name]
    
# setInterval ->
#   console.dir vms
# , 1000

exports.createImage = createImage
exports.deleteImage = deleteImage

exports.readVmCfgs  = readVmCfgs
exports.readImages  = readImages
exports.readIsos    = readIsos

exports.getIsos    = getIsos
exports.getDisks   = getDisks
exports.getVms     = getVms
