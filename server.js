// Generated by CoffeeScript 1.12.2
(function() {
  var LocalStrategy, Q, _, apiworker, app, bcrypt, bodyParser, compression, config, csrf, db, express, flash, outputReorderColumns, passport, session, xlsx;

  Q = require('q');

  _ = require('underscore');

  express = require('express');

  bodyParser = require('body-parser');

  compression = require('compression');

  session = require('express-session');

  flash = require('connect-flash');

  bcrypt = require('bcrypt');

  passport = require('passport');

  xlsx = require('node-xlsx')["default"];

  csrf = require('csurf');

  LocalStrategy = require('passport-local').Strategy;

  config = require('./config');

  db = require('./db');

  apiworker = require('./apiworker');

  app = express();

  app.use(bodyParser.json());

  app.use(bodyParser.urlencoded({
    extended: false
  }));

  if (!config.IS_WORKER) {
    app.use(session({
      secret: config.COOKIE_SECRET,
      resave: false,
      saveUninitialized: false
    }));
    app.use(flash());
    app.use(passport.initialize());
    app.use(passport.session());
    app.use(compression());
    app.use(express["static"]('public'));
    app.use(csrf());
    app.use(function(req, res, next) {
      var csrfToken;
      csrfToken = req.csrfToken();
      res.cookie('XSRF-TOKEN', csrfToken);
      res.locals.csrfToken = csrfToken;
      return next();
    });
    app.use(function(req, res, next) {
      res.locals.messages = req.flash('error');
      return next();
    });
    app.set('views', __dirname + '/views');
    app.set('view engine', 'pug');
    passport.use(new LocalStrategy({
      usernameField: 'email'
    }, function(email, password, done) {
      return db.User.findOne({
        where: {
          email: email
        }
      }).then(function(user) {
        var userValues;
        if (!user) {
          return done(null, false, {
            message: 'Incorrect username or password'
          });
        }
        userValues = user.dataValues;
        if (userValues.hash === null) {
          return done(null, userValues);
        }
        return bcrypt.compare(password, userValues.hash).then(function(result) {
          if (result) {
            return done(null, userValues);
          }
          return done(null, false, {
            message: 'Incorrect username or password'
          });
        });
      });
    }));
    passport.serializeUser(function(user, done) {
      return done(null, user.id);
    });
    passport.deserializeUser(function(id, done) {
      return db.User.findById(id).then(function(user) {
        return done(null, user.dataValues);
      });
    });
  }

  db.createTablesIfNotExist();

  outputReorderColumns = ["snapshot-date", "ASIN", "product-name", "Sales Rank", "product-group", "your-price", "lowest-afn-new-price", "total-units-shipped-last-24-hrs", "total-units-shipped-last-7-days", "total-units-shipped-last-30-days", "total-units-shipped-last-90-days", "total-units-shipped-last-180-days", "total-units-shipped-last-365-days", "num-afn-new-sellers", "Remove from Restock report", "In Stock or OOS - Crenstone", "InBound Crenstone", "Days OOS - Crenstone", "Last 30 days of sales when in stock (-10 sales)", "In Stock or OOS - Oredroc", "InBound Oredroc", "Days OOS - Oredroc", "Last 30 days of sales when in stock - Oredroc", "Total Stock - Both Accounts", "Total Sales both accounts - 30days", "Seasonal Tags", "OEM MFG Part Number", "OEM MFG", "Vendor Part number", "Item Description", "Vendor Name", "Vendor Price", "Quantity needed per ASIN", "Total price of ASIN", "Quantity needed for restock order 3x on 30 day sales", "Quantity needed for restock order 6x on 30 day sales", "Closeout / Retail Tag", "Can Order Again?", "Selling in accounts", "Has stock in accounts", "Crenstone SKU", "Crenstone FNSKU", "your-price", "lowest-afn-new-price", "Below Current Price?", "brand", "your-price", "sales-price", "estimated-fee-total", "estimated-future-fee (Current Selling on Amazon + Future Fulfillment fees)", "estimated-shipping-cost", "total-inventory-cost", "overhead-rate", "profit", "future-profit", "crenstone-units-shipped-last-24-hrs", "crenstone-units-shipped-last-7-days", "crenstone-units-shipped-last-30-days", "crenstone-units-shipped-last-90-days", "crenstone-units-shipped-last-180-days", "crenstone-units-shipped-last-365-days", "your-price", "lowest-afn-new-price", "Below Current Price?", "brand", "your-price", "sales-price", "estimated-fee-total", "estimated-future-fee (Current Selling on Amazon + Future Fulfillment fees)", "estimated-shipping-cost", "total-inventory-cost", "overhead-rate", "profit", "future-profit", "oredroc-units-shipped-last-24-hrs", "oredroc-units-shipped-last-7-days", "oredroc-units-shipped-last-30-days", "oredroc-units-shipped-last-90-days", "oredroc-units-shipped-last-180-days", "oredroc-units-shipped-last-365-days"];

  app.get('/ping', function(req, res) {
    return res.sendStatus(200);
  });

  if (config.IS_WORKER) {
    app.post('/worker', function(req, res) {
      return res.sendStatus(200);
    });
    app.post('/reports/request', function(req, res) {
      return apiworker.requestReports().then(function(result) {
        return res.sendStatus(200);
      });
    });
    app.post('/reports/getlatest', function(req, res) {
      return apiworker.getLatestReports().then(function(result) {
        return res.sendStatus(200);
      });
    });
  } else {
    app.get('/', function(req, res) {
      if (!req.user) {
        return res.redirect('/login');
      } else {
        return res.render('index', {
          user: req.user
        });
      }
    });
    app.get('/reports/download', function(req, res) {
      var crenstoneFeesDateQuery, crenstoneInventoryDateQuery, date, formattedDate, oredrocFeesDateQuery, oredrocInventoryDateQuery;
      if (!req.user) {
        return res.redirect('/');
      } else {
        date = new Date();
        formattedDate = date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate();
        oredrocInventoryDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'oredroc\' AND type=\'inventory-health\'';
        crenstoneInventoryDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'crenstone\' AND type=\'inventory-health\'';
        oredrocFeesDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'oredroc\' AND type=\'fba-fees\'';
        crenstoneFeesDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'crenstone\' AND type=\'fba-fees\'';
        return Q.all([db.sequelize.query(oredrocInventoryDateQuery), db.sequelize.query(crenstoneInventoryDateQuery), db.sequelize.query(oredrocFeesDateQuery), db.sequelize.query(crenstoneFeesDateQuery)]).spread(function(oredrocInventoryDateResult, crenstoneInventoryDateResult, oredrocFeesDateResult, crenstoneFeesDateResult) {
          var crenstoneFeesByDateQuery, crenstoneFeesDate, crenstoneFeesDateFormatted, crenstoneInventoryByDateQuery, crenstoneInventoryDate, crenstoneInventoryDateFormatted, oredrocFeesByDateQuery, oredrocFeesDate, oredrocFeesDateFormatted, oredrocInventoryByDateQuery, oredrocInventoryDate, oredrocInventoryDateFormatted;
          if (oredrocInventoryDateResult[1].rowCount === 0 && crenstoneInventoryDateResult[1].rowCount === 0 && oredrocFeesDateResult[1].rowCount === 0 && crenstoneFeesDateResult[1].rowCount === 0) {
            return res.redirect('/');
          } else {
            oredrocInventoryByDateQuery = 'SELECT * FROM "inventory-health" WHERE seller=\'oredroc\'';
            if (oredrocInventoryDateResult[1].rowCount > 0) {
              oredrocInventoryDate = new Date(oredrocInventoryDateResult[0][0]['snapshot-date']);
              oredrocInventoryDateFormatted = oredrocInventoryDate.getFullYear() + '-' + (oredrocInventoryDate.getMonth() + 1) + '-' + oredrocInventoryDate.getDate();
              oredrocInventoryByDateQuery += ' AND \"snapshot-date\"=\'' + oredrocInventoryDateFormatted + '\'';
            }
            crenstoneInventoryByDateQuery = 'SELECT * FROM "inventory-health" WHERE seller=\'crenstone\'';
            if (crenstoneInventoryDateResult[1].rowCount > 0) {
              crenstoneInventoryDate = new Date(crenstoneInventoryDateResult[0][0]['snapshot-date']);
              crenstoneInventoryDateFormatted = crenstoneInventoryDate.getFullYear() + '-' + (crenstoneInventoryDate.getMonth() + 1) + '-' + crenstoneInventoryDate.getDate();
              crenstoneInventoryByDateQuery += ' AND \"snapshot-date\"=\'' + crenstoneInventoryDateFormatted + '\'';
            }
            oredrocFeesByDateQuery = 'SELECT * FROM "fba-fees" WHERE seller=\'oredroc\'';
            if (oredrocFeesDateResult[1].rowCount > 0) {
              oredrocFeesDate = new Date(oredrocFeesDateResult[0][0]['snapshot-date']);
              oredrocFeesDateFormatted = oredrocFeesDate.getFullYear() + '-' + (oredrocFeesDate.getMonth() + 1) + '-' + oredrocFeesDate.getDate();
              oredrocFeesByDateQuery += ' AND \"snapshot-date\"=\'' + oredrocFeesDateFormatted + '\'';
            }
            crenstoneFeesByDateQuery = 'SELECT * FROM "fba-fees" WHERE seller=\'crenstone\'';
            if (crenstoneFeesDateResult[1].rowCount > 0) {
              crenstoneFeesDate = new Date(crenstoneFeesDateResult[0][0]['snapshot-date']);
              crenstoneFeesDateFormatted = crenstoneFeesDate.getFullYear() + '-' + (crenstoneFeesDate.getMonth() + 1) + '-' + crenstoneFeesDate.getDate();
              crenstoneFeesByDateQuery += ' AND \"snapshot-date\"=\'' + crenstoneFeesDateFormatted + '\'';
            }
            return Q.all([
              db.sequelize.query(oredrocInventoryByDateQuery, {
                type: db.sequelize.QueryTypes.SELECT
              }), db.sequelize.query(oredrocFeesByDateQuery, {
                type: db.sequelize.QueryTypes.SELECT
              }), db.sequelize.query(crenstoneInventoryByDateQuery, {
                type: db.sequelize.QueryTypes.SELECT
              }), db.sequelize.query(crenstoneFeesByDateQuery, {
                type: db.sequelize.QueryTypes.SELECT
              })
            ]).spread(function(oredrocInventoryResult, oredrocFeesResult, crenstoneInventoryResult, crenstoneFeesResult) {
              var buffer, columnNames, data, i, j, k, key, l, len, len1, len2, len3, len4, len5, len6, len7, m, n, o, p, ref, ref1, ref2, ref3, row, rowData, worksheets;
              if (oredrocInventoryResult.length === 0 && oredrocFeesResult.length === 0 && crenstoneInventoryResult.length === 0 && crenstoneFeesResult.length === 0) {
                return res.redirect('/');
              } else {
                worksheets = [];
                if (oredrocInventoryResult.length > 0) {
                  columnNames = _.filter(Object.keys(oredrocInventoryResult[0]), function(key) {
                    return key !== 'id' && key !== 'seller';
                  });
                  data = new Array();
                  data.push(columnNames);
                  for (i = 0, len = oredrocInventoryResult.length; i < len; i++) {
                    row = oredrocInventoryResult[i];
                    rowData = new Array();
                    ref = Object.keys(row);
                    for (j = 0, len1 = ref.length; j < len1; j++) {
                      key = ref[j];
                      if (key === 'snapshot-date') {
                        date = new Date(row[key]);
                        formattedDate = date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate();
                        rowData.push(formattedDate);
                      } else if (key !== 'id' && key !== 'seller') {
                        rowData.push(row[key]);
                      }
                    }
                    data.push(rowData);
                  }
                  worksheets.push({
                    name: "Oredroc Inventory Health",
                    data: data
                  });
                }
                if (oredrocFeesResult.length > 0) {
                  columnNames = _.filter(Object.keys(oredrocFeesResult[0]), function(key) {
                    return key !== 'id' && key !== 'seller';
                  });
                  data = new Array();
                  data.push(columnNames);
                  for (k = 0, len2 = oredrocFeesResult.length; k < len2; k++) {
                    row = oredrocFeesResult[k];
                    rowData = new Array();
                    ref1 = Object.keys(row);
                    for (l = 0, len3 = ref1.length; l < len3; l++) {
                      key = ref1[l];
                      if (key === 'snapshot-date') {
                        date = new Date(row[key]);
                        formattedDate = date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate();
                        rowData.push(formattedDate);
                      } else if (key !== 'id' && key !== 'seller') {
                        rowData.push(row[key]);
                      }
                    }
                    data.push(rowData);
                  }
                  worksheets.push({
                    name: "Oredroc FBA Fees",
                    data: data
                  });
                }
                if (crenstoneInventoryResult.length > 0) {
                  columnNames = _.filter(Object.keys(crenstoneInventoryResult[0]), function(key) {
                    return key !== 'id' && key !== 'seller';
                  });
                  data = new Array();
                  data.push(columnNames);
                  for (m = 0, len4 = crenstoneInventoryResult.length; m < len4; m++) {
                    row = crenstoneInventoryResult[m];
                    rowData = new Array();
                    ref2 = Object.keys(row);
                    for (n = 0, len5 = ref2.length; n < len5; n++) {
                      key = ref2[n];
                      if (key === 'snapshot-date') {
                        date = new Date(row[key]);
                        formattedDate = date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate();
                        rowData.push(formattedDate);
                      } else if (key !== 'id' && key !== 'seller') {
                        rowData.push(row[key]);
                      }
                    }
                    data.push(rowData);
                  }
                  worksheets.push({
                    name: "Crenstone Inventory Health",
                    data: data
                  });
                }
                if (crenstoneFeesResult.length > 0) {
                  columnNames = _.filter(Object.keys(crenstoneFeesResult[0]), function(key) {
                    return key !== 'id' && key !== 'seller';
                  });
                  data = new Array();
                  data.push(columnNames);
                  for (o = 0, len6 = crenstoneFeesResult.length; o < len6; o++) {
                    row = crenstoneFeesResult[o];
                    rowData = new Array();
                    ref3 = Object.keys(row);
                    for (p = 0, len7 = ref3.length; p < len7; p++) {
                      key = ref3[p];
                      if (key === 'snapshot-date') {
                        date = new Date(row[key]);
                        formattedDate = date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate();
                        rowData.push(formattedDate);
                      } else if (key !== 'id' && key !== 'seller') {
                        rowData.push(row[key]);
                      }
                    }
                    data.push(rowData);
                  }
                  worksheets.push({
                    name: "Crenstone FBA Fees",
                    data: data
                  });
                }
                buffer = xlsx.build(worksheets);
                res.type('xlsx');
                res.setHeader('Content-disposition', 'attachment; filename=output.xlsx');
                return res.send(buffer);
              }
            });
          }
        });
      }
    });
    app.get('/signup', function(req, res) {
      if (req.user) {
        if (req.user.hash === null) {
          return res.render('signup');
        } else {
          return res.redirect('/');
        }
      } else {
        return res.redirect('/login');
      }
    });
    app.get('/login', function(req, res) {
      if (req.user) {
        if (req.user.hash === null) {
          return res.redirect('/signup');
        } else {
          return res.redirect('/');
        }
      } else {
        return res.render('login');
      }
    });
    app.get('/logout', function(req, res) {
      if (req.user) {
        req.session.destroy();
      }
      return res.redirect('/');
    });
    app.post('/signup', function(req, res) {
      var password;
      if (!req.user) {
        return res.redirect('/login');
      } else {
        password = req.body.password;
        if (password === req.body.confirmPassword) {
          return db.User.findOne({
            where: {
              email: req.user.email
            }
          }).then(function(user) {
            if (user == null) {
              throw {
                notFound: true
              };
            } else {
              return bcrypt.hash(password, parseInt(config.SALTROUNDS)).then(function(hash) {
                return user.updateAttributes({
                  hash: hash
                });
              }).then(function(user) {
                req.session.destroy();
                return res.redirect('/login');
              });
            }
          });
        } else {
          req.flash('error', 'The passwords do not match');
          return res.redirect('/signup');
        }
      }
    });
    app.post('/login', passport.authenticate('local', {
      failureRedirect: '/login',
      failureFlash: true
    }), function(req, res) {
      if (req.user) {
        if (req.user.hash === null) {
          return res.redirect('/signup');
        } else {
          return res.redirect('/');
        }
      } else {
        return res.redirect('/login');
      }
    });
  }

  app.listen(config.PORT);

}).call(this);
