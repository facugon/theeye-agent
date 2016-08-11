"use strict";

const fs = require('fs');
const md5 = require('md5');
const exec = require('child_process').exec;
const join = require('path').join;
const EventEmitter = require('events').EventEmitter;
const debug = require('debug')('eye:lib:script');

const FILE_MISSING = 'file_missing';
const FILE_OUTDATED = 'file_outdated';

const ScriptOutput = require('./output');

class Script extends EventEmitter {

	constructor (props, options) {
    super();
    this._md5 = props.md5 ,
    this._args = props.args ,
    this._filename = props.filename ,
    this._path = props.path ,
    this._runas = props.runas ;

    if(!props.path) throw new Error('scripts path is required.');
    this._filepath = join(this._path, this._filename);
    this._output = null;
	}

  get filepath() { return this._filepath; }
  get md5() { return this._md5; }
  get filename() { return this._filename; }
  get args() { return this._args; }
  get runas() { return this._runas; }
  get path() { return this._path; }
  get output() { return this._output; }

  checkFile(done){
    fs.exists(this.filepath,(exists)=>{
      if(!exists) return done(false, FILE_MISSING);
      else {
        var buf = fs.readFileSync(this.filepath);
        if( md5(buf) != this.md5 ){
          return done(false, FILE_OUTDATED);
        } else {
          return done(true);
        }
      }
    });
  }

  save(stream, done){
    var writable = fs.createWriteStream(
      this.filepath, { mode:'0755' } 
    );

    stream.on('error',(error)=>{
      if(done) done(error);
    })
    .pipe( writable )
    .on('finish',()=>{
      if(done) done();
    });

    return this;
  }

  run(){
    var args = (this.args||[]).join(' ');
    var filepath = this.filepath;
    var partial = (`${filepath} ${args}`).trim();
    var formatted;

    const runas = this.runas;
    const regex = /%s/;

    if( runas && regex.test(runas) === true ){
      formatted = runas.replace(regex, partial);
    } else {
      formatted = partial;
    }

    return this.execScript(formatted);
  }

  execScript(script){
    const child = exec(script);
    const emitter = this;

    var partials = { stdout:'', stderr:'', log:'' };

    debug('running script "%s"', script);

    child.stdout.on('data',(data) => {
      partials.stdout += data;
      partials.log += data;

      emitter.emit('stdout', data);
    });

    child.stderr.on('data',(data) => {
      partials.stderr += data;
      partials.log += data;

      emitter.emit('stderr', data);
    });

    child.on('close',(code) => {
      this._output = new ScriptOutput({
        code: code,
        stdout: partials.stdout,
        stderr: partials.stderr,
        log: partials.log
      });

      emitter.emit('end', this.output);
    });

    return emitter;
  }
}

module.exports = Script;
