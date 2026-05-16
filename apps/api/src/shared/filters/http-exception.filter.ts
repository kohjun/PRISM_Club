import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse();
    const req = ctx.getRequest();

    const status =
      exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;

    let code = 'INTERNAL_ERROR';
    let message = 'Internal server error';

    if (exception instanceof HttpException) {
      const responseBody = exception.getResponse();
      if (typeof responseBody === 'string') {
        message = responseBody;
        code = exception.name.replace(/Exception$/, '').toUpperCase();
      } else if (typeof responseBody === 'object' && responseBody !== null) {
        const body = responseBody as { message?: string | string[]; error?: string };
        message = Array.isArray(body.message) ? body.message.join(', ') : body.message ?? message;
        code = body.error?.toUpperCase().replace(/\s/g, '_') ?? code;
      }
    } else if (exception instanceof Error) {
      message = exception.message;
      this.logger.error(exception.stack);
    }

    res.status(status).json({
      error: {
        code,
        message,
        requestId: req.headers['x-request-id'] ?? null,
      },
    });
  }
}
