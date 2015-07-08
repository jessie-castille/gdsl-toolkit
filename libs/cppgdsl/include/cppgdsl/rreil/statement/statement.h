/*
 * statement.h
 *
 *  Created on: May 21, 2014
 *      Author: Julian Kranz
 */

#pragma once
#include <iosfwd>
#include <string>
#include <vector>

#include "cppgdsl/rreil/statement/statement_visitor.h"

namespace gdsl {
namespace rreil {

// Acts as the base class for all expression and statement types in the RREIL
// language.
class statement {
 public:
  virtual ~statement() {}
  virtual void accept(statement_visitor &v) = 0;
 
 private:
  virtual void put(std::ostream &out) const = 0;
  friend std::ostream &operator<<(std::ostream &out,
                                  const statement &statement);
};

typedef std::vector<rreil::statement*> statements_t;

// Appends the string representation of the given statement to the output
// stream.
std::ostream &operator<<(std::ostream &out, const statement &statement);

std::string to_string(const statement &statement);

}  // namespace rreil
}  // namespace gdsl
