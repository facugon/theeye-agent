'use strict';

var psaux = require('iar-ps-list')();
var Worker = require('../index').define('psaux');

module.exports = Worker;

Worker.prototype.getData = function(next) {
  var self = this;

  psaux.parsed(function(error, data) {
    if (error) {
      self.debug.error('unable to get data');
      self.debug.error(error);
      return next(new Error('unable to get data'));
    } else {
      return next(null,{
        psaux: data,
      });
    }
  });

  psaux.clearInterval();
};

Worker.prototype.submitWork = function(data,next) {
  this.connection.create({
    route: '/:customer/psaux/:hostname',
    body: data,
    failure:function(err){ next&&next(err); },
    success:function(body){ next&&next(null,body); }
  });
};
