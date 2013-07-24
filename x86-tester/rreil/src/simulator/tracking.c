/*
 * simulator_tracking.c
 *
 *  Created on: 11.05.2013
 *      Author: jucs
 */

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <rreil/rreil.h>
#include <simulator/simulator.h>
#include <simulator/regacc.h>
#include <simulator/tracking.h>
#include <util.h>
#include <x86.h>

enum simulator_access_type {
	SIMULATOR_ACCESS_TYPE_READ, SIMULATOR_ACCESS_TYPE_WRITE
};

static void tracking_variable_access_trace(struct simulator_trace *trace,
		struct rreil_variable *variable, size_t bit_length,
		enum simulator_access_type type) {
	if(variable->id->type != RREIL_ID_TYPE_X86)
		return;

	struct register_access *access;
	if(type == SIMULATOR_ACCESS_TYPE_READ)
		access = &trace->read;
	else
		access = &trace->written;

	uint8_t *data = (uint8_t*)malloc(bit_length / 8 + 1);
	for(size_t i = 0; i < bit_length / 8 + 1; ++i)
		data[i] = 0xff;

	simulator_register_generic_write(&access->x86_registers[variable->id->x86],
			data, bit_length, variable->offset);

	free(data);

	size_t index = variable->id->x86;
	char found = 0;
	for(size_t i = 0; i < access->indices_length; ++i)
		if(access->indices[i] == index) {
			found = 1;
			break;
		}
	if(!found)
		util_array_generic_add((void**)&access->indices, &index, sizeof(index),
				&access->indices_length, &access->indices_size);
}

static void tracking_linear_trace(struct simulator_trace *trace,
		struct rreil_linear *linear, size_t bit_length) {
	switch(linear->type) {
		case RREIL_LINEAR_TYPE_VARIABLE: {
			tracking_variable_access_trace(trace, linear->variable, bit_length,
					SIMULATOR_ACCESS_TYPE_READ);
			break;
		}
		case RREIL_LINEAR_TYPE_IMMEDIATE: {
			break;
		}
		case RREIL_LINEAR_TYPE_SUM: {
			tracking_linear_trace(trace, linear->sum.opnd1, bit_length);
			tracking_linear_trace(trace, linear->sum.opnd2, bit_length);
			break;
		}
		case RREIL_LINEAR_TYPE_DIFFERENCE: {
			tracking_linear_trace(trace, linear->difference.opnd1, bit_length);
			tracking_linear_trace(trace, linear->difference.opnd2, bit_length);
			break;
		}
		case RREIL_LINEAR_TYPE_SCALE: {
			tracking_linear_trace(trace, linear->scale.opnd, bit_length);
			break;
		}
	}
}

static size_t tracking_comparator_trace(struct simulator_trace *trace,
		struct rreil_comparator *comparator) {
	tracking_linear_trace(trace, comparator->arity2.opnd1, comparator->arity2.size);
	tracking_linear_trace(trace, comparator->arity2.opnd2, comparator->arity2.size);
	return 1;
}

static void tracking_sexpr_trace(struct simulator_trace *trace, struct rreil_sexpr *sexpr,
		size_t bit_length) {
	switch(sexpr->type) {
		case RREIL_SEXPR_TYPE_LIN: {
			tracking_linear_trace(trace, sexpr->lin, bit_length);
			break;
		}
		case RREIL_SEXPR_TYPE_CMP: {
			tracking_comparator_trace(trace, sexpr->cmp);
			break;
		}
	}
}

static size_t tracking_op_trace(struct simulator_trace *trace, struct rreil_op *op) {
	switch(op->type) {
		case RREIL_OP_TYPE_LIN: {
			tracking_linear_trace(trace, op->lin.opnd1, op->lin.size);
			return op->lin.size;
		}
		case RREIL_OP_TYPE_MUL: {
			tracking_linear_trace(trace, op->mul.opnd1, op->mul.size);
			tracking_linear_trace(trace, op->mul.opnd2, op->mul.size);
			return op->mul.size;
		}
		case RREIL_OP_TYPE_DIV: {
			tracking_linear_trace(trace, op->div.opnd1, op->div.size);
			tracking_linear_trace(trace, op->div.opnd2, op->div.size);
			return op->div.size;
		}
		case RREIL_OP_TYPE_DIVS: {
			tracking_linear_trace(trace, op->divs.opnd1, op->divs.size);
			tracking_linear_trace(trace, op->divs.opnd2, op->divs.size);
			return op->divs.size;
		}
		case RREIL_OP_TYPE_MOD: {
			tracking_linear_trace(trace, op->mod.opnd1, op->mod.size);
			tracking_linear_trace(trace, op->mod.opnd2, op->mod.size);
			return op->mod.size;
		}
		case RREIL_OP_TYPE_SHL: {
			tracking_linear_trace(trace, op->shl.opnd1, op->shl.size);
			tracking_linear_trace(trace, op->shl.opnd2, op->shl.size);
			return op->shl.size;
		}
		case RREIL_OP_TYPE_SHR: {
			tracking_linear_trace(trace, op->shr.opnd1, op->shr.size);
			tracking_linear_trace(trace, op->shr.opnd2, op->shr.size);
			return op->shr.size;
		}
		case RREIL_OP_TYPE_SHRS: {
			tracking_linear_trace(trace, op->shrs.opnd1, op->shrs.size);
			tracking_linear_trace(trace, op->shrs.opnd2, op->shrs.size);
			return op->shrs.size;
		}
		case RREIL_OP_TYPE_AND: {
			tracking_linear_trace(trace, op->and.opnd1, op->and.size);
			tracking_linear_trace(trace, op->and.opnd2, op->and.size);
			return op->and.size;
		}
		case RREIL_OP_TYPE_OR: {
			tracking_linear_trace(trace, op->or.opnd1, op->or.size);
			tracking_linear_trace(trace, op->or.opnd2, op->or.size);
			return op->or.size;
		}
		case RREIL_OP_TYPE_XOR: {
			tracking_linear_trace(trace, op->xor.opnd1, op->xor.size);
			tracking_linear_trace(trace, op->xor.opnd2, op->xor.size);
			return op->xor.size;
		}
		case RREIL_OP_TYPE_SX: {
			tracking_linear_trace(trace, op->sx.opnd, op->sx.fromsize);
			return op->sx.size;
		}
		case RREIL_OP_TYPE_ZX: {
			tracking_linear_trace(trace, op->zx.opnd, op->zx.fromsize);
			return op->zx.size;
		}
		case RREIL_OP_TYPE_CMP: {
			return tracking_comparator_trace(trace, op->cmp);
		}
		case RREIL_OP_TYPE_ARB: {
			return op->arb.size;
		}
		default:
			return 0;
	}
}

static void tracking_statement_trace(struct simulator_trace *trace,
		struct rreil_statement *statement) {
	switch(statement->type) {
		case RREIL_STATEMENT_TYPE_ASSIGN: {
			size_t bits = tracking_op_trace(trace, statement->assign.rhs);
			tracking_variable_access_trace(trace, statement->assign.lhs, bits,
					SIMULATOR_ACCESS_TYPE_WRITE);
			break;
		}
		case RREIL_STATEMENT_TYPE_LOAD: {
			fprintf(stderr,
					"Simulator: Unable to trace RREIL_STATEMENT_TYPE_LOAD, not implemented.\n");
			break;
		}
		case RREIL_STATEMENT_TYPE_STORE: {
			fprintf(stderr,
					"Simulator: Unable to trace RREIL_STATEMENT_TYPE_STORE, not implemented.\n");
			break;
		}
		case RREIL_STATEMENT_TYPE_ITE: {
			/*
			 * Todo: fix size
			 */
			tracking_sexpr_trace(trace, statement->ite.cond, 1);
			tracking_statements_trace(trace, statement->ite.then_branch);
			tracking_statements_trace(trace, statement->ite.else_branch);
			break;
		}
		case RREIL_STATEMENT_TYPE_WHILE: {
			tracking_sexpr_trace(trace, statement->while_.cond, 1);
			tracking_statements_trace(trace, statement->while_.body);
			break;
		}
		case RREIL_STATEMENT_TYPE_CBRANCH: {
			fprintf(stderr,
					"Simulator: Unable to track RREIL_STATEMENT_TYPE_CBRANCH, not implemented.\n");
			break;
		}
		case RREIL_STATEMENT_TYPE_BRANCH: {
			fprintf(stderr,
					"Simulator: Unable to track RREIL_STATEMENT_TYPE_BRANCH, not implemented.\n");
			break;
		}
	}
}

void tracking_statements_trace(struct simulator_trace *trace,
		struct rreil_statements *statements) {
	for(size_t i = 0; i < statements->statements_length; ++i)
		tracking_statement_trace(trace, statements->statements[i]);
}

//void simulator_register_access_register_add(struct register_access *access,
//		enum rreil_id_x86 id) {
//	if(access->indices_length >= access->indices_size) {
//		access->indices_size = access->indices_size ? access->indices_size << 1 : 8;
//		access->indices = (size_t*)realloc(access->indices,
//				sizeof(size_t) * access->indices_size);
//	}
//	access->indices[access->indices_length++] = id;
//}

struct simulator_trace *tracking_trace_init() {
	struct simulator_trace *trace = (struct simulator_trace*)malloc(
			sizeof(struct simulator_trace));

	void init_rw(struct register_access *access) {
		access->x86_registers = (struct register_*)calloc(X86_ID_COUNT,
				sizeof(struct register_));

		void init_register(enum x86_id x86) {
			size_t size = x86_amd64_sizeof(x86);
			struct register_ *reg = &access->x86_registers[x86];
			reg->data = (uint8_t*)calloc(size / 8, 1);
			reg->data_bit_length = size;
			reg->data_size = size / 8;
		}

		for(size_t i = 0; i < X86_ID_COUNT; ++i)
			init_register((enum x86_id)i);

		access->indices = NULL;
		access->indices_length = 0;
		access->indices_size = 0;
	}

	init_rw(&trace->read);
	init_rw(&trace->written);

	return trace;
}

void tracking_trace_free(struct simulator_trace *trace) {
	void access_clear(struct register_access *access) {
		for(size_t i = 0; i < X86_ID_COUNT; ++i) {
			struct register_ *reg = &access->x86_registers[i];
			free(reg->data);
		}
		free(access->indices);
		free(access->x86_registers);
	}

	access_clear(&trace->read);
	access_clear(&trace->written);

	free(trace);
}

void tracking_trace_print(struct simulator_trace *trace) {
	void access_print(struct register_access *access) {
		for(size_t i = 0; i < access->indices_length; ++i) {
			enum x86_id id_x86 = (enum x86_id)access->indices[i];
			struct register_ *reg = &access->x86_registers[id_x86];

			printf("Register ");
			x86_id_print(id_x86);
			printf(": ");

			size_t rest = 0;
			size_t reg_size = x86_amd64_sizeof(id_x86);
			if(reg_size > reg->data_bit_length)
				rest = reg_size - reg->data_bit_length;
			for(size_t i = 0; i < rest / 8; ++i)
				printf("00");
			if(reg->data_bit_length) {
				if(reg->data_bit_length % 8) {
					uint8_t top = reg->data[reg->data_bit_length / 8];
					uint8_t mask = (1 << (reg->data_bit_length % 8)) - 1;
					printf("%02x", (top & mask));
				}
				for(size_t i = reg->data_bit_length / 8; i > 0; --i)
					printf("%02x", reg->data[i - 1]);
			}
			printf("\n");
		}
	}

	printf("Read registers:\n");
	access_print(&trace->read);
	printf("Written registers:\n");
	access_print(&trace->written);
}